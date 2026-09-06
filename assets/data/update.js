const fs = require("node:fs").promises;
const path = require("node:path");

/**
 * Hàm hỗ trợ sắp xếp các chuỗi phiên bản theo thứ tự giảm dần (Semantic Versioning)
 */
function sortVersions(versions) {
  if (!Array.isArray(versions)) return [];
  return [...new Set(versions)].sort((a, b) => {
    const partsA = String(a)
      .split(".")
      .map((v) => Number.parseInt(v, 10) || 0);
    const partsB = String(b)
      .split(".")
      .map((v) => Number.parseInt(v, 10) || 0);
    for (let i = 0; i < Math.max(partsA.length, partsB.length); i++) {
      const numA = partsA[i] || 0;
      const numB = partsB[i] || 0;
      if (numA > numB) return -1;
      if (numA < numB) return 1;
    }
    return 0;
  });
}

/**
 * Lọc lấy phiên bản Patch mới nhất cho mỗi cụm Major.Minor và sắp xếp giảm dần
 */
function sortVersionsObject(versionsObj) {
  if (!versionsObj || typeof versionsObj !== "object") return {};
  const allKeys = Object.keys(versionsObj);
  if (allKeys.length === 0) return {};

  const sortedKeys = sortVersions(allKeys);
  const latestPatchVersions = {};

  sortedKeys.forEach((v) => {
    const parts = v.split(".");
    const key = parts.length >= 2 ? `${parts[0]}.${parts[1]}` : v;
    if (!latestPatchVersions[key]) latestPatchVersions[key] = v;
  });

  const result = {};
  sortVersions(Object.values(latestPatchVersions)).forEach((k) => {
    result[k] = versionsObj[k];
  });
  return result;
}

/**
 * Helper fetch danh sách bản phát hành MariaDB theo matcher tệp
 */
async function fetchMariadbReleases(fileMatcher) {
  const res = await fetch("https://downloads.mariadb.org/rest-api/mariadb/");
  const data = await res.json();
  const versions = {};
  if (!data.major_releases) return versions;

  for (const r of data.major_releases) {
    if (r.release_status === "Preview") continue;
    const majorRes = await fetch(
      `https://downloads.mariadb.org/rest-api/mariadb/${r.release_id}`,
    );
    const majorData = await majorRes.json();
    if (!majorData.releases) continue;

    for (const [releaseVer, details] of Object.entries(majorData.releases)) {
      const match = details.files?.find(fileMatcher);
      if (match?.file_download_url) {
        versions[releaseVer] = match.file_download_url;
      }
    }
  }
  return versions;
}

/**
 * Helper fetch danh sách bản phát hành Node.js theo phiên bản major tối thiểu và urlBuilder
 */
async function fetchNodejsReleases({ minMajor, urlBuilder }) {
  const res = await fetch("https://nodejs.org/download/release/index.json");
  const data = await res.json();
  const versions = {};
  const ltsLabels = {};
  data
    .filter(
      (v) =>
        Number.parseInt(v.version.replace("v", "").split(".")[0], 10) >=
        minMajor,
    )
    .forEach((v) => {
      const ver = v.version.replace("v", "");
      versions[ver] = urlBuilder(ver);
      if (v.lts) {
        ltsLabels[ver] = typeof v.lts === "string" ? v.lts : "LTS";
      }
    });
  return { versions, ltsLabels };
}

/**
 * Helper fetch danh sách bản phát hành MySQL từ Docker Hub tags theo urlBuilder
 */
async function fetchMysqlReleases(urlBuilder) {
  const regex = /^(\d+\.\d+\.\d+)$/;
  const versions = {};
  for (let p = 1; p <= 3; p++) {
    const res = await fetch(
      `https://hub.docker.com/v2/namespaces/library/repositories/mysql/tags?page=${p}&page_size=100`,
    );
    const data = await res.json();
    data.results?.forEach((t) => {
      if (regex.test(t.name)) {
        const majorMinor = t.name.split(".").slice(0, 2).join(".");
        versions[t.name] = urlBuilder(t.name, majorMinor);
      }
    });
  }
  return versions;
}

/**
 * Helper fetch danh sách bản phát hành Elasticsearch từ GitHub tags theo urlBuilder
 */
async function fetchElasticsearchReleases(urlBuilder) {
  const res = await fetch(
    "https://api.github.com/repos/elastic/elasticsearch/tags",
    {
      headers: {
        Accept: "application/vnd.github.v3+json",
        "User-Agent": "Ponta-Update",
      },
    },
  );
  const data = await res.json();
  const versions = {};
  if (!Array.isArray(data)) return {};

  data.forEach((t) => {
    const ver = t.name.replace(/^v/i, "");
    const parts = ver.split(".").map(Number);
    if (parts[0] >= 8) {
      versions[ver] = urlBuilder(ver);
    }
  });
  return versions;
}

// === CÁC HÀM FETCH DỮ LIỆU WINDOWS ===

const fetchersWindows = {
  nodejs() {
    return fetchNodejsReleases({
      minMajor: 4,
      urlBuilder: (ver) =>
        `https://nodejs.org/dist/v${ver}/node-v${ver}-win-x64.zip`,
    });
  },

  async php(prefix) {
    const baseUrl = "https://downloads.php.net/~windows/releases/archives/";
    const res = await fetch(baseUrl);
    const html = await res.text();
    const versions = {};
    const regex = new RegExp(
      String.raw`php-(${prefix}\.\d+)-nts-Win32-.*?-x64\.zip`,
      "gi",
    );
    const matches = html.matchAll(regex);
    for (const match of matches) {
      versions[match[1]] = baseUrl + match[0];
    }
    return versions;
  },

  mysql() {
    return fetchMysqlReleases(
      (name, majorMinor) =>
        `https://cdn.mysql.com/Downloads/MySQL-${majorMinor}/mysql-${name}-winx64.zip`,
    );
  },

  mariadb() {
    return fetchMariadbReleases((f) => f.file_name?.endsWith("-winx64.zip"));
  },

  async mongodb() {
    const res = await fetch("https://downloads.mongodb.org/current.json");
    const json = await res.json();
    const versions = {};
    json.versions?.forEach((v) => {
      if (v.version.match(/-(rc|alpha|beta)/i)) return;
      const win = v.downloads?.find(
        (d) =>
          d.target === "windows" && d.arch === "x86_64" && d.edition === "base",
      );
      if (win?.archive) versions[v.version] = win.archive.url;
    });
    return versions;
  },

  async postgresql() {
    const res = await fetch(
      "https://www.enterprisedb.com/download-postgresql-binaries",
    );
    const html = await res.text();
    const versions = {};
    const versionRegex =
      /Version\s*<!--\s*-->([\d.]+)(?:<span[^>]*>.*?<\/span>)?<\/span>[\s\S]*?<a\s+href="([^"]+)"[^>]*>\s*<img\s+alt="Windows x86-64"/gi;
    const matches = html.matchAll(versionRegex);

    for (const match of matches) {
      const version = match[1];
      let url = match[2];
      if (
        html.substring(match.index, match.index + 500).includes("Not supported")
      ) {
        continue;
      }
      if (url.startsWith("/") || !url.startsWith("http")) {
        url = "https://www.enterprisedb.com" + url;
      }
      versions[version] = url;
    }
    return versions;
  },

  async apache() {
    const res = await fetch("https://www.apachelounge.com/download/");
    const html = await res.text();
    const regex =
      /href="([^"]*?\/binaries\/httpd-([\d.]+)-\d+-win64-.*?\.zip)"/gi;
    const versions = {};
    for (const m of html.matchAll(regex)) {
      versions[m[2]] = m[1].startsWith("http")
        ? m[1]
        : `https://www.apachelounge.com${m[1]}`;
    }
    return versions;
  },

  async github(repoPath, options = {}) {
    const res = await fetch(
      `https://api.github.com/repos/${repoPath}/releases`,
      {
        headers: {
          Accept: "application/vnd.github.v3+json",
          "User-Agent": "Ponta-Update",
        },
      },
    );
    const data = await res.json();
    const versions = {};
    if (!Array.isArray(data)) return {};
    data.forEach((r) => {
      if (r.prerelease && !options.includePrereleases) return;
      const ver = r.tag_name.replace(/^(v|release-|redis-|redis|r(?=\d))/i, "");
      let url = `https://github.com/${repoPath}/archive/refs/tags/${r.tag_name}.zip`;
      if (r.assets?.length > 0) {
        let asset;
        if (repoPath === "mongodb-js/compass") {
          url = null;
          asset = r.assets.find(
            (a) =>
              a.name.toLowerCase().includes("win32-x64") &&
              a.name.toLowerCase().endsWith(".zip") &&
              !a.name.toLowerCase().includes("isolated") &&
              !a.name.toLowerCase().includes("readonly"),
          );
        } else if (repoPath === "HeidiSQL/HeidiSQL") {
          url = null;
          asset = r.assets.find((a) =>
            a.name.toLowerCase().endsWith("_64_portable.zip"),
          );
        } else {
          asset = r.assets.find(
            (a) =>
              (a.name.toLowerCase().includes("win") ||
                a.name.toLowerCase().includes("x64")) &&
              (a.name.toLowerCase().endsWith(".zip") ||
                a.name.toLowerCase().endsWith(".msi") ||
                a.name.toLowerCase().endsWith(".exe")) &&
              (repoPath !== "meilisearch/meilisearch" ||
                !a.name.toLowerCase().includes("enterprise")),
          );
          if (!asset)
            asset = r.assets.find(
              (a) =>
                a.name.toLowerCase().endsWith(".zip") ||
                a.name.toLowerCase().endsWith(".msi") ||
                a.name.toLowerCase().endsWith(".exe"),
            );
        }
        if (asset) url = asset.browser_download_url;
      }
      if (url) {
        versions[ver] = url;
      }
    });
    return versions;
  },

  elasticsearch() {
    return fetchElasticsearchReleases(
      (ver) =>
        `https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ver}-windows-x86_64.zip`,
    );
  },
};

// === CÁC HÀM FETCH DỮ LIỆU LINUX ===

const fetchersLinux = {
  nodejs() {
    return fetchNodejsReleases({
      minMajor: 18,
      urlBuilder: (ver) =>
        `https://nodejs.org/dist/v${ver}/node-v${ver}-linux-x64.tar.gz`,
    });
  },

  async caddy() {
    const res = await fetch(
      "https://api.github.com/repos/caddyserver/caddy/releases",
      {
        headers: {
          Accept: "application/vnd.github.v3+json",
          "User-Agent": "Ponta-Update",
        },
      },
    );
    const data = await res.json();
    const versions = {};
    if (!Array.isArray(data)) return {};
    data.forEach((r) => {
      if (r.prerelease) return;
      const ver = r.tag_name.replace(/^v/i, "");
      const asset = r.assets?.find(
        (a) =>
          a.name.includes("linux_amd64.tar.gz") ||
          a.name.includes("linux_x86_64.tar.gz"),
      );
      if (asset) {
        versions[ver] = asset.browser_download_url;
      }
    });
    return versions;
  },

  async nginx() {
    // Static Nginx binaries for Linux from Jakub Jirutka (Alpine/musl static builds)
    const res = await fetch("https://jirutka.github.io/nginx-binaries/index.json");
    const data = await res.json();
    const versions = {};
    if (data && Array.isArray(data.contents)) {
      data.contents
        .filter(
          (item) =>
            item.os === "linux" &&
            item.arch === "x86_64" &&
            item.name === "nginx" &&
            !item.variant,
        )
        .forEach((item) => {
          versions[item.version] =
            `https://jirutka.github.io/nginx-binaries/${item.filename}`;
        });
    }
    return versions;
  },

  mysql() {
    return fetchMysqlReleases(
      (name, majorMinor) =>
        `https://cdn.mysql.com/Downloads/MySQL-${majorMinor}/mysql-${name}-linux-glibc2.28-x86_64.tar.xz`,
    );
  },

  mariadb() {
    return fetchMariadbReleases(
      (f) =>
        f.file_name?.endsWith("-linux-systemd-x86_64.tar.gz") ||
        f.file_name?.endsWith("-linux-x86_64.tar.gz"),
    );
  },

  async mongodb() {
    const res = await fetch("https://downloads.mongodb.org/current.json");
    const json = await res.json();
    const versions = {};
    json.versions?.forEach((v) => {
      if (v.version.match(/-(rc|alpha|beta)/i)) return;
      const dl = v.downloads?.find(
        (d) =>
          (d.target === "ubuntu2204" ||
            d.target === "ubuntu2004" ||
            d.target === "debian12" ||
            d.target === "linux") &&
          d.arch === "x86_64" &&
          d.edition === "base" &&
          !d.archive?.url?.includes("enterprise"),
      );
      if (dl?.archive?.url) {
        // Replace concrete target with {mongo_distro} placeholder
        versions[v.version] = dl.archive.url.replace(
          /-(ubuntu2204|ubuntu2004|ubuntu2404|debian12)-/,
          "-{mongo_distro}-",
        );
      }
    });
    return versions;
  },

  async meilisearch() {
    const res = await fetch(
      "https://api.github.com/repos/meilisearch/meilisearch/releases",
      {
        headers: {
          Accept: "application/vnd.github.v3+json",
          "User-Agent": "Ponta-Update",
        },
      },
    );
    const data = await res.json();
    const versions = {};
    if (!Array.isArray(data)) return {};
    data.forEach((r) => {
      if (r.prerelease) return;
      const ver = r.tag_name.replace(/^v/i, "");
      const asset = r.assets?.find(
        (a) => a.name === "meilisearch-linux-amd64",
      );
      if (asset) {
        versions[ver] = asset.browser_download_url;
      }
    });
    return versions;
  },

  async rustfs() {
    const res = await fetch(
      "https://api.github.com/repos/rustfs/rustfs/releases",
      {
        headers: {
          Accept: "application/vnd.github.v3+json",
          "User-Agent": "Ponta-Update",
        },
      },
    );
    const data = await res.json();
    const versions = {};
    if (!Array.isArray(data)) return {};
    data.forEach((r) => {
      const ver = r.tag_name.replace(/^v/i, "");
      const asset = r.assets?.find(
        (a) =>
          a.name.toLowerCase().includes("linux") &&
          a.name.toLowerCase().includes("x86_64") &&
          a.name.toLowerCase().endsWith(".tar.gz"),
      );
      if (asset) {
        versions[ver] = asset.browser_download_url;
      }
    });
    return versions;
  },

  elasticsearch() {
    return fetchElasticsearchReleases(
      (ver) =>
        `https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ver}-linux-x86_64.tar.gz`,
    );
  },
};

// === CẤU TRÚC DANH MỤC GỐC WINDOWS & LINUX ===

const PHP_VERSIONS = ["8.5", "8.4", "8.3", "8.2"];

function createWindowsPhpApps(versions) {
  return versions.map((ver) => ({
    id: `php${ver.replace(".", "")}`,
    name: `PHP ${ver}`,
    description: `Hypertext Preprocessor v${ver}`,
    category: "runtime",
    group_name: "php",
    exec_file: "php-cgi.exe",
    cli_file: "php.exe",
    prefix: ver,
  }));
}

function createServicePackageManagerCommands({
  debPackage,
  debServiceName = debPackage,
  rpmPackage,
  rpmServiceName = rpmPackage,
}) {
  return {
    ubuntu: [
      "sudo apt-get update",
      `sudo apt-get install -y ${debPackage}`,
      `sudo systemctl disable --now ${debServiceName}`,
    ],
    debian: [
      "sudo apt-get update",
      `sudo apt-get install -y ${debPackage}`,
      `sudo systemctl disable --now ${debServiceName}`,
    ],
    centos: [
      `sudo dnf install -y ${rpmPackage}`,
      `sudo systemctl disable --now ${rpmServiceName}`,
    ],
  };
}

function createLinuxPhpApps(versions) {
  return versions.map((ver) => ({
    id: `php${ver.replace(".", "")}`,
    name: `PHP ${ver}`,
    description: `Hypertext Preprocessor v${ver}`,
    category: "runtime",
    group_name: "php",
    exec_file: `php-fpm${ver}`,
    cli_file: `php${ver}`,
    prefix: ver,
    install_method: "package_manager",
    package_manager_commands: {
      ubuntu: [
        "sudo apt-get update",
        "sudo apt-get install -y software-properties-common",
        "sudo add-apt-repository -y ppa:ondrej/php",
        "sudo apt-get update",
        `sudo apt-get install -y php${ver}-fpm php${ver}-cli php${ver}-common php${ver}-curl php${ver}-mbstring php${ver}-mysql php${ver}-xml php${ver}-zip`,
        `sudo systemctl disable --now php${ver}-fpm`,
      ],
      debian: [
        "sudo apt-get update",
        "sudo apt-get install -y software-properties-common apt-transport-https lsb-release ca-certificates",
        "curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb",
        "sudo dpkg -i /tmp/debsuryorg-archive-keyring.deb",
        'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ {codename} main" | sudo tee /etc/apt/sources.list.d/php.list',
        "sudo apt-get update",
        `sudo apt-get install -y php${ver}-fpm php${ver}-cli php${ver}-common php${ver}-curl php${ver}-mbstring php${ver}-mysql php${ver}-xml php${ver}-zip`,
        `sudo systemctl disable --now php${ver}-fpm`,
      ],
      centos: [
        "sudo dnf install -y epel-release",
        "sudo dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm",
        "sudo dnf module reset -y php",
        `sudo dnf module enable -y php:remi-${ver}`,
        "sudo dnf install -y php php-fpm php-cli php-common php-mysqlnd php-mbstring php-xml php-zip",
        "sudo systemctl disable --now php-fpm",
      ],
    },
    versions: {
      [ver]: "package_manager",
    },
  }));
}

const COMMON_APP_DEFINITIONS = {
  pyenv: {
    id: "pyenv",
    name: "pyenv",
    description: "Python version management tool.",
    category: "runtime",
    group_name: "python",
    exec_file: null,
  },
  nodejs: {
    id: "nodejs",
    name: "Node.js",
    description: "JavaScript runtime built on Chrome's V8 engine.",
    category: "runtime",
    group_name: "nodejs",
  },
  nginx: {
    id: "nginx",
    name: "Nginx",
    description: "Lightweight, less memory, concurrent ability",
    category: "webserver",
    group_name: "webserver",
  },
  apache: {
    id: "apache",
    name: "Apache",
    description: "World No. 1 web server",
    category: "webserver",
    group_name: "webserver",
  },
  caddy: {
    id: "caddy",
    name: "Caddy",
    description: "Fast, extensible web server with a simple configuration",
    category: "webserver",
    group_name: "webserver",
  },
  mysql: {
    id: "mysql",
    name: "MySQL",
    description: "MySQL Community Server",
    category: "database",
    group_name: "database",
    default_username: "root",
    default_password: "",
  },
  mariadb: {
    id: "mariadb",
    name: "MariaDB",
    description: "MariaDB Database Server",
    category: "database",
    group_name: "database",
    default_username: "root",
    default_password: "",
  },
  redis: {
    id: "redis",
    category: "database",
    group_name: "redis",
  },
  mongodb: {
    id: "mongodb",
    name: "MongoDB",
    description: "NoSQL document-oriented database.",
    category: "database",
    group_name: "database",
  },
  postgresql: {
    id: "postgresql",
    name: "PostgreSQL",
    description: "Advanced open source relational database.",
    category: "database",
    group_name: "database",
  },
  phpMyAdmin: {
    id: "phpMyAdmin",
    name: "phpMyAdmin",
    description: "Web interface for MySQL and MariaDB.",
    category: "tool",
    group_name: "database",
    exec_file: "index.php",
    cli_file: "index.php",
  },
  rustfs: {
    id: "rustfs",
    name: "RustFS",
    description: "High-performance S3-compatible object storage server.",
    category: "storage",
    group_name: "storage",
    default_username: "rustfsadmin",
    default_password: "rustfsadmin",
    repo: "rustfs/rustfs",
    includePrereleases: true,
  },
  meilisearch: {
    id: "meilisearch",
    name: "Meilisearch",
    description: "A lightning-fast, open-source search engine.",
    category: "database",
    group_name: "meilisearch",
  },
  elasticsearch: {
    id: "elasticsearch",
    name: "Elasticsearch",
    description: "Distributed, RESTful search and analytics engine.",
    category: "database",
    group_name: "elasticsearch",
    default_username: "elastic",
  },
};

function makeBinaryApp(base, execFile, cliFile, extra = {}) {
  const result = {
    id: base.id,
    name: extra.name || base.name,
    description: extra.description || base.description,
    category: base.category,
    group_name: base.group_name,
    exec_file: execFile,
    cli_file: cliFile,
  };
  if (base.default_username !== undefined) {
    result.default_username = base.default_username;
  }
  if (base.default_password !== undefined) {
    result.default_password = base.default_password;
  }
  if (extra.repo || base.repo) {
    result.repo = extra.repo || base.repo;
  }
  if (base.includePrereleases !== undefined) {
    result.includePrereleases = base.includePrereleases;
  }
  return result;
}

function makeLinuxPackageManagerApp(
  base,
  {
    execFile,
    cliFile,
    debPackage,
    debServiceName,
    rpmPackage,
    rpmServiceName,
    name,
    description,
  },
) {
  return {
    id: base.id,
    name: name || base.name,
    description: description || base.description,
    category: base.category,
    group_name: base.group_name,
    exec_file: execFile,
    cli_file: cliFile,
    install_method: "package_manager",
    package_manager_commands: createServicePackageManagerCommands({
      debPackage,
      debServiceName,
      rpmPackage,
      rpmServiceName,
    }),
    versions: {
      system: "package_manager",
    },
  };
}

const baseWindowsApps = [
  {
    ...COMMON_APP_DEFINITIONS.pyenv,
    cli_file: "pyenv.bat",
    versions: {
      latest: "https://github.com/pyenv-win/pyenv-win/archive/master.zip",
    },
  },
  makeBinaryApp(COMMON_APP_DEFINITIONS.nodejs, "node.exe", "node.exe"),
  makeBinaryApp(COMMON_APP_DEFINITIONS.nginx, "nginx.exe", "nginx.exe", {
    repo: "nginx/nginx",
  }),
  makeBinaryApp(COMMON_APP_DEFINITIONS.apache, "httpd.exe", "httpd.exe"),
  makeBinaryApp(COMMON_APP_DEFINITIONS.caddy, "caddy.exe", "caddy.exe", {
    repo: "caddyserver/caddy",
  }),
  ...createWindowsPhpApps(PHP_VERSIONS),
  makeBinaryApp(COMMON_APP_DEFINITIONS.mysql, "mysqld.exe", "mysql.exe"),
  makeBinaryApp(COMMON_APP_DEFINITIONS.mariadb, "mariadbd.exe", "mariadb.exe"),
  makeBinaryApp(
    COMMON_APP_DEFINITIONS.redis,
    "redis-server.exe",
    "redis-cli.exe",
    {
      name: "Redis",
      description: "In-memory data structure store.",
      repo: "zkteco-home/redis-windows",
    },
  ),
  makeBinaryApp(COMMON_APP_DEFINITIONS.mongodb, "mongod.exe", "mongos.exe"),
  makeBinaryApp(COMMON_APP_DEFINITIONS.postgresql, "postgres.exe", "psql.exe"),
  {
    ...COMMON_APP_DEFINITIONS.phpMyAdmin,
    versions: {
      latest:
        "https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip",
      "5.2.3":
        "https://files.phpmyadmin.net/phpMyAdmin/5.2.3/phpMyAdmin-5.2.3-all-languages.zip",
      "6.0":
        "https://files.phpmyadmin.net/snapshots/phpMyAdmin-6.0+snapshot-all-languages.zip",
    },
  },
  {
    id: "heidisql",
    name: "HeidiSQL",
    description:
      "A powerful and easy-to-use tool for managing MySQL, MariaDB and PostgreSQL.",
    category: "tool",
    group_name: "database",
    exec_file: "heidisql.exe",
    cli_file: "heidisql.exe",
    repo: "HeidiSQL/HeidiSQL",
  },
  {
    id: "mongodb-compass",
    name: "MongoDB Compass",
    description: "The GUI for MongoDB.",
    category: "tool",
    group_name: "database",
    exec_file: "MongoDBCompass.exe",
    cli_file: "MongoDBCompass.exe",
    repo: "mongodb-js/compass",
  },
  makeBinaryApp(COMMON_APP_DEFINITIONS.rustfs, "rustfs.exe", "rustfs.exe"),
  makeBinaryApp(
    COMMON_APP_DEFINITIONS.meilisearch,
    "meilisearch.exe",
    "meilisearch.exe",
    {
      repo: "meilisearch/meilisearch",
    },
  ),
  makeBinaryApp(
    COMMON_APP_DEFINITIONS.elasticsearch,
    "elasticsearch.bat",
    "elasticsearch.bat",
  ),
];

const baseLinuxApps = [
  {
    ...COMMON_APP_DEFINITIONS.pyenv,
    cli_file: "pyenv",
    versions: {
      latest:
        "https://github.com/pyenv/pyenv/archive/refs/heads/master.tar.gz",
    },
  },
  makeBinaryApp(COMMON_APP_DEFINITIONS.nodejs, "node", "node"),
  makeBinaryApp(COMMON_APP_DEFINITIONS.caddy, "caddy", "caddy"),
  makeBinaryApp(COMMON_APP_DEFINITIONS.nginx, "nginx", "nginx"),
  makeLinuxPackageManagerApp(COMMON_APP_DEFINITIONS.apache, {
    execFile: "apache2",
    cliFile: "apache2",
    debPackage: "apache2",
    rpmPackage: "httpd",
  }),
  ...createLinuxPhpApps(PHP_VERSIONS),
  makeBinaryApp(COMMON_APP_DEFINITIONS.mysql, "mysqld", "mysql"),
  makeBinaryApp(COMMON_APP_DEFINITIONS.mariadb, "mariadbd", "mariadb"),
  makeLinuxPackageManagerApp(COMMON_APP_DEFINITIONS.redis, {
    name: "Redis",
    description: "High-performance in-memory data structure store.",
    execFile: "redis-server",
    cliFile: "redis-cli",
    debPackage: "redis-server",
    rpmPackage: "redis",
  }),
  makeBinaryApp(COMMON_APP_DEFINITIONS.mongodb, "mongod", "mongos"),
  makeLinuxPackageManagerApp(COMMON_APP_DEFINITIONS.postgresql, {
    execFile: "postgres",
    cliFile: "psql",
    debPackage: "postgresql postgresql-contrib",
    debServiceName: "postgresql",
    rpmPackage: "postgresql-server postgresql-contrib",
    rpmServiceName: "postgresql",
  }),
  {
    ...COMMON_APP_DEFINITIONS.phpMyAdmin,
    versions: {
      latest:
        "https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip",
      "5.2.2":
        "https://files.phpmyadmin.net/phpMyAdmin/5.2.2/phpMyAdmin-5.2.2-all-languages.zip",
    },
  },
  makeBinaryApp(COMMON_APP_DEFINITIONS.rustfs, "rustfs", "rustfs"),
  makeBinaryApp(
    COMMON_APP_DEFINITIONS.meilisearch,
    "meilisearch",
    "meilisearch",
  ),
  makeBinaryApp(
    COMMON_APP_DEFINITIONS.elasticsearch,
    "elasticsearch",
    "elasticsearch",
  ),
];

// === HÀM THỰC THI CHÍNH ===

async function loadExistingCatalog(outputPath, existingPath) {
  try {
    return JSON.parse(await fs.readFile(outputPath, "utf8"));
  } catch (_) {
    // Primary output file not found or unreadable; fall back to existing template.
    try {
      return JSON.parse(await fs.readFile(existingPath, "utf8"));
    } catch (_ignored) {
      // Existing catalog file may not exist yet on initial run; safe to ignore.
      return null;
    }
  }
}

async function fetchAppVersions(app, fetchers, platformName) {
  try {
    if (fetchers[app.id]) {
      return await fetchers[app.id]();
    }
    if (app.prefix && fetchers.php) {
      return await fetchers.php(app.prefix);
    }
    if (app.repo && fetchers.github) {
      return await fetchers.github(app.repo, {
        includePrereleases: app.includePrereleases,
      });
    }
  } catch (err) {
    console.error(
      `[${platformName}] Lỗi khi lấy dữ liệu cho ${app.name}:`,
      err.message,
    );
  }
  return null;
}

function applyFetchedVersions(app, fetchedResult) {
  if (!fetchedResult) return;

  if (app.id === "nodejs" && fetchedResult.versions) {
    app.versions = sortVersionsObject(fetchedResult.versions);
    if (
      fetchedResult.ltsLabels &&
      Object.keys(fetchedResult.ltsLabels).length > 0
    ) {
      app.lts_labels = fetchedResult.ltsLabels;
    }
    return;
  }

  if (
    typeof fetchedResult === "object" &&
    Object.keys(fetchedResult).length > 0
  ) {
    app.versions = sortVersionsObject(fetchedResult);
  }
}

function applyFallbackVersions(app, oldData) {
  if (
    app.install_method === "package_manager" &&
    app.package_manager_commands
  ) {
    return;
  }

  if (!app.versions || Object.keys(app.versions).length === 0) {
    const oldApp = oldData?.apps?.find((a) => a.id === app.id);
    if (oldApp?.versions) {
      app.versions = oldApp.versions;
      if (oldApp.lts_labels) {
        app.lts_labels = oldApp.lts_labels;
      }
    }
  }
}

async function updatePlatformCatalog({
  platformName,
  baseApps,
  fetchers,
  outputFileName,
  existingFileName,
}) {
  const outputPath = path.join(__dirname, outputFileName);
  const existingPath = path.join(__dirname, existingFileName);

  console.log(
    `[${new Date().toLocaleString()}] [${platformName}] Bắt đầu cập nhật dữ liệu...`,
  );

  const oldData = await loadExistingCatalog(outputPath, existingPath);
  const catalogObject = {
    version: "1.1.0",
    lastUpdated: "",
    apps: structuredClone(baseApps),
  };

  await Promise.all(
    catalogObject.apps.map(async (app) => {
      const fetched = await fetchAppVersions(app, fetchers, platformName);
      applyFetchedVersions(app, fetched);
      applyFallbackVersions(app, oldData);
    }),
  );

  const hasChanged =
    JSON.stringify(catalogObject.apps) !== JSON.stringify(oldData?.apps);

  if (hasChanged || !oldData) {
    catalogObject.lastUpdated = new Date().toISOString();
    await fs.writeFile(
      outputPath,
      JSON.stringify(catalogObject, null, 2),
      "utf8",
    );
    console.log(
      `[${new Date().toLocaleString()}] [${platformName}] Thành công: Đã cập nhật ${outputFileName}.`,
    );
  } else {
    console.log(
      `[${new Date().toLocaleString()}] [${platformName}] Hoàn tất: Không có thay đổi nào.`,
    );
  }
}

try {
  // 1. Cập nhật Windows Catalog (new-apps.json)
  await updatePlatformCatalog({
    platformName: "Windows",
    baseApps: baseWindowsApps,
    fetchers: fetchersWindows,
    outputFileName: "new-apps.json",
    existingFileName: "apps.json",
  });

  // 2. Cập nhật Linux Catalog (new-apps-linux.json)
  await updatePlatformCatalog({
    platformName: "Linux",
    baseApps: baseLinuxApps,
    fetchers: fetchersLinux,
    outputFileName: "new-apps-linux.json",
    existingFileName: "apps-linux.json",
  });
} catch (error) {
  console.error("Lỗi cập nhật tổng thể:", error);
}
