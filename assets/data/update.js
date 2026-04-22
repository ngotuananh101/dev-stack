const fs = require("fs").promises;
const path = require("path");
const { versions } = require("process");

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

// === CÁC HÀM FETCH DỮ LIỆU ===

const fetchers = {
  async nodejs() {
    const res = await fetch("https://nodejs.org/download/release/index.json");
    const data = await res.json();
    const versions = {};
    data
      .filter((v) => parseInt(v.version.replace("v", "").split(".")[0]) >= 4)
      .forEach((v) => {
        const ver = v.version.replace("v", "");
        versions[ver] =
          `https://nodejs.org/dist/v${ver}/node-v${ver}-win-x64.zip`;
      });
    return versions;
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
      // Giảm xuống 3 trang để tối ưu tốc độ
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
        // Get version info
        const majorRes = await fetch(
          `https://downloads.mariadb.org/rest-api/mariadb/${r.release_id}`,
        );
        const majorData = await majorRes.json();
        if (!majorData.releases) continue;

        for (const [releaseVer, details] of Object.entries(
          majorData.releases,
        )) {
          let hasWinZip = false;
          for (const file of details.files) {
            if (file.file_name.endsWith("-winx64.zip")) {
              versions[releaseVer] = file.file_download_url;
              hasWinZip = true;
              break;
            }
          }
          if (hasWinZip) {
            break;
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

  async github(repoPath) {
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
      if (r.prerelease) return;
      const ver = r.tag_name.replace(/^(v|release-|redis-|redis|r(?=\d))/i, "");
      let url = `https://github.com/${repoPath}/archive/refs/tags/${r.tag_name}.zip`;
      if (r.assets?.length > 0) {
        let asset;
        if (repoPath === "mongodb-js/compass") {
          asset = r.assets.find(
            (a) =>
              a.name.toLowerCase().includes("win32-x64") &&
              a.name.toLowerCase().endsWith(".zip") &&
              !a.name.toLowerCase().includes("isolated") &&
              !a.name.toLowerCase().includes("readonly"),
          );
        } else if (repoPath === "HeidiSQL/HeidiSQL") {
          asset = r.assets.find((a) =>
            a.name.toLowerCase().endsWith("_64_Portable.zip"),
          );
        } else {
          asset = r.assets.find(
            (a) =>
              (a.name.toLowerCase().includes("win") ||
                a.name.toLowerCase().includes("x64")) &&
              (a.name.toLowerCase().endsWith(".zip") ||
                a.name.toLowerCase().endsWith(".msi")),
          );
          if (!asset)
            asset = r.assets.find(
              (a) =>
                a.name.toLowerCase().endsWith(".zip") ||
                a.name.toLowerCase().endsWith(".msi"),
            );
        }
        if (asset) url = asset.browser_download_url;
      }
      versions[ver] = url;
    });
    return versions;
  },
};

// === CẤU TRÚC DỮ LIỆU GỐC ===

let baseDataObject = {
  version: "1.1.0",
  lastUpdated: "",
  apps: [
    {
      id: "pyenv",
      name: "pyenv",
      description: "Python version management tool.",
      category: "runtime",
      group_name: "python",
      exec_file: "pyenv.exe",
      cli_file: "pyenv.exe",
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
      id: "mysql",
      name: "MySQL",
      description: "MySQL Community Server",
      category: "database",
      group_name: "database",
      exec_file: "mysqld.exe",
      cli_file: "mysql.exe",
    },
    {
      id: "mariadb",
      name: "MariaDB",
      description: "MariaDB Database Server",
      category: "database",
      group_name: "database",
      exec_file: "mariadbd.exe",
      cli_file: "mariadb.exe",
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
  ],
};

// === HÀM CHÍNH ===

async function updateAppsJson() {
  const filePath = path.join(__dirname, "new-apps.json");
  console.log(`[${new Date().toLocaleString()}] Bắt đầu cập nhật dữ liệu...`);

  try {
    // Đọc dữ liệu cũ để so sánh
    let oldData = null;
    try {
      oldData = JSON.parse(await fs.readFile(filePath, "utf8"));
    } catch (e) {}

    // Tạo danh sách các task chạy song song
    const tasks = baseDataObject.apps.map(async (app) => {
      try {
        let v;
        if (app.id === "nodejs") v = await fetchers.nodejs();
        else if (app.prefix) v = await fetchers.php(app.prefix);
        else if (app.repo) v = await fetchers.github(app.repo);
        else if (fetchers[app.id]) v = await fetchers[app.id]();

        if (v) app.versions = sortVersionsObject(v);
      } catch (err) {
        console.error(`Lỗi khi lấy dữ liệu cho ${app.name}:`, err.message);
        // Giữ lại dữ liệu cũ nếu lỗi
        const oldApp = oldData?.apps?.find((a) => a.id === app.id);
        if (oldApp) app.versions = oldApp.versions;
      }
    });

    await Promise.all(tasks);

    // Kiểm tra thay đổi
    const hasChanged =
      JSON.stringify(baseDataObject.apps) !== JSON.stringify(oldData?.apps);

    if (hasChanged || !oldData) {
      baseDataObject.lastUpdated = new Date().toISOString();
      await fs.writeFile(
        filePath,
        JSON.stringify(baseDataObject, null, 2),
        "utf8",
      );
      console.log(
        `[${new Date().toLocaleString()}] Thành công: Đã cập nhật phiên bản mới.`,
      );
    } else {
      console.log(
        `[${new Date().toLocaleString()}] Hoàn tất: Không có thay đổi nào.`,
      );
    }
  } catch (error) {
    console.error("Lỗi hệ thống:", error);
  }
}

updateAppsJson();
