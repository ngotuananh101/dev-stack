const fs = require("fs").promises;
const path = require("path");

/**
 * Hàm hỗ trợ sắp xếp các chuỗi phiên bản theo thứ tự giảm dần (Semantic Versioning)
 */
function sortVersions(versions) {
  if (!Array.isArray(versions)) return [];
  return [...new Set(versions)].sort((a, b) => {
    const partsA = String(a)
      .split(".")
      .map((v) => parseInt(v) || 0);
    const partsB = String(b)
      .split(".")
      .map((v) => parseInt(v) || 0);
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

// === CÁC HÀM FETCH DỮ LIỆU WINDOWS ===

const fetchersWindows = {
  async nodejs() {
    const res = await fetch("https://nodejs.org/download/release/index.json");
    const data = await res.json();
    const versions = {};
    const ltsLabels = {};
    data
      .filter((v) => parseInt(v.version.replace("v", "").split(".")[0]) >= 4)
      .forEach((v) => {
        const ver = v.version.replace("v", "");
        versions[ver] =
          `https://nodejs.org/dist/v${ver}/node-v${ver}-win-x64.zip`;
        if (v.lts) {
          ltsLabels[ver] = typeof v.lts === "string" ? v.lts : "LTS";
        }
      });
    return { versions, ltsLabels };
  },

  async php(prefix) {
    const baseUrl = "https://downloads.php.net/~windows/releases/archives/";
    const res = await fetch(baseUrl);
    const html = await res.text();
    const versions = {};
    const regex = new RegExp(
      `php-(${prefix}\\.\\d+)-nts-Win32-.*?-x64\\.zip`,
      "gi",
    );
    const matches = html.matchAll(regex);
    for (const match of matches) {
      versions[match[1]] = baseUrl + match[0];
    }
    return versions;
  },

  async mysql() {
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
          versions[t.name] =
            `https://cdn.mysql.com/Downloads/MySQL-${majorMinor}/mysql-${t.name}-winx64.zip`;
        }
      });
    }
    return versions;
  },

  async mariadb() {
    const res = await fetch("https://downloads.mariadb.org/rest-api/mariadb/");
    const data = await res.json();
    const versions = {};
    if (!data.major_releases) return versions;

    for (const r of data.major_releases) {
      if (r.release_status !== "Preview") {
        const majorRes = await fetch(
          `https://downloads.mariadb.org/rest-api/mariadb/${r.release_id}`,
        );
        const majorData = await majorRes.json();
        if (!majorData.releases) continue;

        for (const [releaseVer, details] of Object.entries(
          majorData.releases,
        )) {
          for (const file of details.files || []) {
            if (file.file_name.endsWith("-winx64.zip")) {
              versions[releaseVer] = file.file_download_url;
              break;
            }
          }
        }
      }
    }
    return versions;
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
      /href="([^"]*?\/binaries\/httpd-([\d.]+)-[\d]+-win64-.*?\.zip)"/gi;
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

  async elasticsearch() {
    const res = await fetch(
      `https://api.github.com/repos/elastic/elasticsearch/tags`,
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
        versions[ver] =
          `https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ver}-windows-x86_64.zip`;
      }
    });
    return versions;
  },
};

// === CÁC HÀM FETCH DỮ LIỆU LINUX ===

const fetchersLinux = {
  async nodejs() {
    const res = await fetch("https://nodejs.org/download/release/index.json");
    const data = await res.json();
    const versions = {};
    const ltsLabels = {};
    data
      .filter((v) => parseInt(v.version.replace("v", "").split(".")[0]) >= 18)
      .forEach((v) => {
        const ver = v.version.replace("v", "");
        versions[ver] =
          `https://nodejs.org/dist/v${ver}/node-v${ver}-linux-x64.tar.gz`;
        if (v.lts) {
          ltsLabels[ver] = typeof v.lts === "string" ? v.lts : "LTS";
        }
      });
    return { versions, ltsLabels };
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

  async mysql() {
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
          versions[t.name] =
            `https://cdn.mysql.com/Downloads/MySQL-${majorMinor}/mysql-${t.name}-linux-glibc2.28-x86_64.tar.xz`;
        }
      });
    }
    return versions;
  },

  async mariadb() {
    const res = await fetch("https://downloads.mariadb.org/rest-api/mariadb/");
    const data = await res.json();
    const versions = {};
    if (!data.major_releases) return versions;

    for (const r of data.major_releases) {
      if (r.release_status !== "Preview") {
        const majorRes = await fetch(
          `https://downloads.mariadb.org/rest-api/mariadb/${r.release_id}`,
        );
        const majorData = await majorRes.json();
        if (!majorData.releases) continue;

        for (const [releaseVer, details] of Object.entries(
          majorData.releases,
        )) {
          for (const file of details.files || []) {
            if (
              file.file_name.endsWith("-linux-systemd-x86_64.tar.gz") ||
              file.file_name.endsWith("-linux-x86_64.tar.gz")
            ) {
              versions[releaseVer] = file.file_download_url;
              break;
            }
          }
        }
      }
    }
    return versions;
  },

  async redis() {
    // Valkey official prebuilt Linux binary tarballs from download.valkey.io
    const versions = {};
    const candidateVersions = [
      "9.1.1", "9.1.0", "9.0.5", "9.0.4", "9.0.0",
      "8.1.9", "8.1.8", "8.1.7", "8.1.0",
      "8.0.3", "8.0.2", "8.0.1", "8.0.0",
      "7.2.7", "7.2.6", "7.2.5", "7.2.4"
    ];
    const distros = ["jammy", "focal", "noble"];

    for (const ver of candidateVersions) {
      for (const d of distros) {
        const url = `https://download.valkey.io/releases/valkey-${ver}-${d}-x86_64.tar.gz`;
        try {
          const res = await fetch(url, { method: "HEAD" });
          if (res.status === 200) {
            versions[ver] = url;
            break;
          }
        } catch (_) {}
      }
    }
    return versions;
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
        versions[v.version] = dl.archive.url;
      }
    });
    return versions;
  },

  async postgresql() {
    const res = await fetch(
      "https://repo1.maven.org/maven2/io/zonky/test/postgres/embedded-postgres-binaries-linux-amd64/maven-metadata.xml",
    );
    const xml = await res.text();
    const matches = [...xml.matchAll(/<version>(.*?)<\/version>/g)].map(
      (m) => m[1],
    );
    const versions = {};
    matches.forEach((ver) => {
      // Version e.g. 17.2.0 -> key 17.2 or 17.2.0
      const parts = ver.split(".");
      const key = parts.length >= 2 ? `${parts[0]}.${parts[1]}` : ver;
      versions[key] =
        `https://repo1.maven.org/maven2/io/zonky/test/postgres/embedded-postgres-binaries-linux-amd64/${ver}/embedded-postgres-binaries-linux-amd64-${ver}.jar`;
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

  async elasticsearch() {
    const res = await fetch(
      `https://api.github.com/repos/elastic/elasticsearch/tags`,
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
        versions[ver] =
          `https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ver}-linux-x86_64.tar.gz`;
      }
    });
    return versions;
  },
};

// === CẤU TRÚC DANH MỤC GỐC WINDOWS ===

let baseWindowsApps = [
  {
    id: "pyenv",
    name: "pyenv",
    description: "Python version management tool.",
    category: "runtime",
    group_name: "python",
    exec_file: null,
    cli_file: "pyenv.bat",
    versions: {
      latest: "https://github.com/pyenv-win/pyenv-win/archive/master.zip",
    },
  },
  {
    id: "nodejs",
    name: "Node.js",
    description: "JavaScript runtime built on Chrome's V8 engine.",
    category: "runtime",
    group_name: "nodejs",
    exec_file: "node.exe",
    cli_file: "node.exe",
  },
  {
    id: "nginx",
    name: "Nginx",
    description: "Lightweight, less memory, concurrent ability",
    category: "webserver",
    group_name: "webserver",
    exec_file: "nginx.exe",
    cli_file: "nginx.exe",
    repo: "nginx/nginx",
  },
  {
    id: "apache",
    name: "Apache",
    description: "World No. 1 web server",
    category: "webserver",
    group_name: "webserver",
    exec_file: "httpd.exe",
    cli_file: "httpd.exe",
  },
  {
    id: "caddy",
    name: "Caddy",
    description: "Fast, extensible web server with a simple configuration",
    category: "webserver",
    group_name: "webserver",
    exec_file: "caddy.exe",
    cli_file: "caddy.exe",
    repo: "caddyserver/caddy",
  },
  {
    id: "php85",
    name: "PHP 8.5",
    description: "Hypertext Preprocessor v8.5",
    category: "runtime",
    group_name: "php",
    exec_file: "php-cgi.exe",
    cli_file: "php.exe",
    prefix: "8.5",
  },
  {
    id: "php84",
    name: "PHP 8.4",
    description: "Hypertext Preprocessor v8.4",
    category: "runtime",
    group_name: "php",
    exec_file: "php-cgi.exe",
    cli_file: "php.exe",
    prefix: "8.4",
  },
  {
    id: "php83",
    name: "PHP 8.3",
    description: "Hypertext Preprocessor v8.3",
    category: "runtime",
    group_name: "php",
    exec_file: "php-cgi.exe",
    cli_file: "php.exe",
    prefix: "8.3",
  },
  {
    id: "php82",
    name: "PHP 8.2",
    description: "Hypertext Preprocessor v8.2",
    category: "runtime",
    group_name: "php",
    exec_file: "php-cgi.exe",
    cli_file: "php.exe",
    prefix: "8.2",
  },
  {
    id: "mysql",
    name: "MySQL",
    description: "MySQL Community Server",
    category: "database",
    group_name: "database",
    exec_file: "mysqld.exe",
    cli_file: "mysql.exe",
    default_username: "root",
    default_password: "",
  },
  {
    id: "mariadb",
    name: "MariaDB",
    description: "MariaDB Database Server",
    category: "database",
    group_name: "database",
    exec_file: "mariadbd.exe",
    cli_file: "mariadb.exe",
    default_username: "root",
    default_password: "",
  },
  {
    id: "redis",
    name: "Redis",
    description: "In-memory data structure store.",
    category: "database",
    group_name: "redis",
    exec_file: "redis-server.exe",
    cli_file: "redis-cli.exe",
    repo: "zkteco-home/redis-windows",
  },
  {
    id: "mongodb",
    name: "MongoDB",
    description: "NoSQL document-oriented database.",
    category: "database",
    group_name: "database",
    exec_file: "mongod.exe",
    cli_file: "mongos.exe",
  },
  {
    id: "postgresql",
    name: "PostgreSQL",
    description: "Advanced open source relational database.",
    category: "database",
    group_name: "database",
    exec_file: "postgres.exe",
    cli_file: "psql.exe",
  },
  {
    id: "phpMyAdmin",
    name: "phpMyAdmin",
    description: "Web interface for MySQL and MariaDB.",
    category: "tool",
    group_name: "database",
    exec_file: "index.php",
    cli_file: "index.php",
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
  {
    id: "rustfs",
    name: "RustFS",
    description: "High-performance S3-compatible object storage server.",
    category: "storage",
    group_name: "storage",
    exec_file: "rustfs.exe",
    cli_file: "rustfs.exe",
    default_username: "rustfsadmin",
    default_password: "rustfsadmin",
    repo: "rustfs/rustfs",
    includePrereleases: true,
  },
  {
    id: "meilisearch",
    name: "Meilisearch",
    description: "A lightning-fast, open-source search engine.",
    category: "database",
    group_name: "meilisearch",
    exec_file: "meilisearch.exe",
    cli_file: "meilisearch.exe",
    repo: "meilisearch/meilisearch",
  },
  {
    id: "elasticsearch",
    name: "Elasticsearch",
    description: "Distributed, RESTful search and analytics engine.",
    category: "database",
    group_name: "elasticsearch",
    exec_file: "elasticsearch.bat",
    cli_file: "elasticsearch.bat",
    default_username: "elastic",
  },
];

// === CẤU TRÚC DANH MỤC GỐC LINUX ===

let baseLinuxApps = [
  {
    id: "pyenv",
    name: "pyenv",
    description: "Python version management tool.",
    category: "runtime",
    group_name: "python",
    exec_file: null,
    cli_file: "pyenv",
    versions: {
      latest: "https://github.com/pyenv/pyenv/archive/refs/heads/master.tar.gz",
    },
  },
  {
    id: "nodejs",
    name: "Node.js",
    description: "JavaScript runtime built on Chrome's V8 engine.",
    category: "runtime",
    group_name: "nodejs",
    exec_file: "node",
    cli_file: "node",
  },
  {
    id: "caddy",
    name: "Caddy",
    description: "Fast, extensible web server with a simple configuration",
    category: "webserver",
    group_name: "webserver",
    exec_file: "caddy",
    cli_file: "caddy",
  },
  {
    id: "nginx",
    name: "Nginx",
    description: "Lightweight, less memory, concurrent ability",
    category: "webserver",
    group_name: "webserver",
    exec_file: "nginx",
    cli_file: "nginx",
  },
  {
    id: "php85",
    name: "PHP 8.5",
    description: "Hypertext Preprocessor v8.5",
    category: "runtime",
    group_name: "php",
    exec_file: "php",
    cli_file: "php",
    prefix: "8.5",
  },
  {
    id: "php84",
    name: "PHP 8.4",
    description: "Hypertext Preprocessor v8.4",
    category: "runtime",
    group_name: "php",
    exec_file: "php",
    cli_file: "php",
    prefix: "8.4",
  },
  {
    id: "php83",
    name: "PHP 8.3",
    description: "Hypertext Preprocessor v8.3",
    category: "runtime",
    group_name: "php",
    exec_file: "php",
    cli_file: "php",
    prefix: "8.3",
  },
  {
    id: "php82",
    name: "PHP 8.2",
    description: "Hypertext Preprocessor v8.2",
    category: "runtime",
    group_name: "php",
    exec_file: "php",
    cli_file: "php",
    prefix: "8.2",
  },
  {
    id: "mysql",
    name: "MySQL",
    description: "MySQL Community Server",
    category: "database",
    group_name: "database",
    exec_file: "mysqld",
    cli_file: "mysql",
    default_username: "root",
    default_password: "",
  },
  {
    id: "mariadb",
    name: "MariaDB",
    description: "MariaDB Database Server",
    category: "database",
    group_name: "database",
    exec_file: "mariadbd",
    cli_file: "mariadb",
    default_username: "root",
    default_password: "",
  },
  {
    id: "redis",
    name: "Redis (Valkey)",
    description: "High-performance in-memory data structure store (Valkey engine).",
    category: "database",
    group_name: "redis",
    exec_file: "valkey-server",
    cli_file: "valkey-cli",
  },
  {
    id: "mongodb",
    name: "MongoDB",
    description: "NoSQL document-oriented database.",
    category: "database",
    group_name: "database",
    exec_file: "mongod",
    cli_file: "mongos",
  },
  {
    id: "postgresql",
    name: "PostgreSQL",
    description: "Advanced open source relational database.",
    category: "database",
    group_name: "database",
    exec_file: "postgres",
    cli_file: "psql",
  },
  {
    id: "phpMyAdmin",
    name: "phpMyAdmin",
    description: "Web interface for MySQL and MariaDB.",
    category: "tool",
    group_name: "database",
    exec_file: "index.php",
    cli_file: "index.php",
    versions: {
      latest:
        "https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip",
      "5.2.2":
        "https://files.phpmyadmin.net/phpMyAdmin/5.2.2/phpMyAdmin-5.2.2-all-languages.zip",
    },
  },
  {
    id: "rustfs",
    name: "RustFS",
    description: "High-performance S3-compatible object storage server.",
    category: "storage",
    group_name: "storage",
    exec_file: "rustfs",
    cli_file: "rustfs",
    default_username: "rustfsadmin",
    default_password: "rustfsadmin",
    repo: "rustfs/rustfs",
    includePrereleases: true,
  },
  {
    id: "meilisearch",
    name: "Meilisearch",
    description: "A lightning-fast, open-source search engine.",
    category: "database",
    group_name: "meilisearch",
    exec_file: "meilisearch",
    cli_file: "meilisearch",
  },
  {
    id: "elasticsearch",
    name: "Elasticsearch",
    description: "Distributed, RESTful search and analytics engine.",
    category: "database",
    group_name: "elasticsearch",
    exec_file: "elasticsearch",
    cli_file: "elasticsearch",
    default_username: "elastic",
  },
];

// === HÀM THỰC THI CHÍNH ===

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

  let oldData = null;
  try {
    oldData = JSON.parse(await fs.readFile(outputPath, "utf8"));
  } catch (e) {
    try {
      oldData = JSON.parse(await fs.readFile(existingPath, "utf8"));
    } catch (_) {}
  }

  const catalogObject = {
    version: "1.1.0",
    lastUpdated: "",
    apps: JSON.parse(JSON.stringify(baseApps)),
  };

  const tasks = catalogObject.apps.map(async (app) => {
    try {
      let v;
      if (fetchers[app.id]) {
        v = await fetchers[app.id]();
      } else if (app.prefix && fetchers.php) {
        v = await fetchers.php(app.prefix);
      } else if (app.repo && fetchers.github) {
        v = await fetchers.github(app.repo, {
          includePrereleases: app.includePrereleases,
        });
      }

      if (v) {
        if (app.id === "nodejs" && v.versions) {
          app.versions = sortVersionsObject(v.versions);
          if (v.ltsLabels && Object.keys(v.ltsLabels).length > 0) {
            app.lts_labels = v.ltsLabels;
          }
        } else if (typeof v === "object" && Object.keys(v).length > 0) {
          app.versions = sortVersionsObject(v);
        }
      }
    } catch (err) {
      console.error(
        `[${platformName}] Lỗi khi lấy dữ liệu cho ${app.name}:`,
        err.message,
      );
    }

    // Giữ lại dữ liệu cũ nếu fetch không có kết quả mới hoặc lỗi
    if (!app.versions || Object.keys(app.versions).length === 0) {
      const oldApp = oldData?.apps?.find((a) => a.id === app.id);
      if (oldApp && oldApp.versions) {
        app.versions = oldApp.versions;
        if (oldApp.lts_labels) app.lts_labels = oldApp.lts_labels;
      }
    }
  });

  await Promise.all(tasks);

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

async function main() {
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
}

main();
