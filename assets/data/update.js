const fs = require('fs').promises;
const path = require('path');

/**
 * Hàm hỗ trợ sắp xếp các chuỗi phiên bản theo thứ tự giảm dần (Semantic Versioning)
 */
function sortVersions(versions) {
  if (!Array.isArray(versions)) return [];
  
  return [...new Set(versions)].sort((a, b) => {
    const partsA = String(a).split('.').map(v => parseInt(v) || 0);
    const partsB = String(b).split('.').map(v => parseInt(v) || 0);
    
    // So sánh từng thành phần của phiên bản
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
 * Hàm hỗ trợ sắp xếp và trả về object { version: url } theo thứ tự giảm dần
 * Đồng thời lọc chỉ lấy phiên bản Patch mới nhất cho mỗi cụm Major.Minor
 */
function sortVersionsObject(versionsObj) {
  if (!versionsObj || typeof versionsObj !== 'object') return {};
  
  const allKeys = Object.keys(versionsObj);
  if (allKeys.length === 0) return {};

  const sortedKeys = sortVersions(allKeys);
  const latestPatchVersions = {};
  
  // Duyệt qua danh sách đã sắp xếp (giảm dần)
  // Bản đầu tiên gặp cho mỗi Major.Minor sẽ là bản mới nhất
  sortedKeys.forEach(v => {
    const parts = v.split('.');
    // Chỉ xử lý các phiên bản có dạng X.Y.Z
    if (parts.length >= 2) {
      const majorMinor = `${parts[0]}.${parts[1]}`;
      if (!latestPatchVersions[majorMinor]) {
        latestPatchVersions[majorMinor] = v;
      }
    } else {
      // Các trường hợp đặc biệt không theo X.Y.Z
      if (!latestPatchVersions[v]) {
        latestPatchVersions[v] = v;
      }
    }
  });

  // Xây dựng kết quả cuối cùng từ các bản đã lọc
  const filteredKeys = sortVersions(Object.values(latestPatchVersions));
  const result = {};
  filteredKeys.forEach(k => {
    result[k] = versionsObj[k];
  });
  
  return result;
}

let baseDataObject = {
  version: "1.1.0",
  lastUpdated: "2026-04-18T11:07:14.436Z",
  apps: [
    {
      id: "pyenv",
      name: "pyenv",
      description: "Python version management tool. Easily switch between multiple Python versions.",
      category: "runtime",
      group_name: "python",
      exec_file: "pyenv.exe",
      cli_file: "pyenv.exe",
    },
    {
      id: "nodejs",
      name: "Node.js",
      description: "JavaScript runtime built on Chrome's V8 JavaScript engine.",
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
      exec_file: "php.exe",
      cli_file: "php.exe",
    },
    {
      id: "php83",
      name: "PHP 8.3",
      description: "Hypertext Preprocessor v8.3",
      category: "runtime",
      group_name: "php",
      exec_file: "php.exe",
      cli_file: "php.exe",
    },
    {
      id: "php84",
      name: "PHP 8.4",
      description: "Hypertext Preprocessor v8.4",
      category: "runtime",
      group_name: "php",
      exec_file: "php.exe",
      cli_file: "php.exe",
    },
    {
      id: "php85",
      name: "PHP 8.5",
      description: "Hypertext Preprocessor v8.5",
      category: "runtime",
      group_name: "php",
      exec_file: "php.exe",
      cli_file: "php.exe",
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
    },
    {
      id: "apache",
      name: "Apache",
      description: "World No. 1, fast, reliable and scalable through simple APIs",
      category: "webserver",
      group_name: "webserver",
      exec_file: "httpd.exe",
      cli_file: "httpd.exe",
    },
    {
      id: "redis",
      name: "Redis",
      description: "In-memory data structure store, used as a database, cache, and message broker.",
      category: "database",
      group_name: "redis",
      exec_file: "redis-server.exe",
      cli_file: "redis-cli.exe",
    },
    {
      id: "mongodb",
      name: "MongoDB",
      description: "NoSQL document-oriented database program.",
      category: "database",
      group_name: "database",
      exec_file: "mongod.exe",
      cli_file: "mongo.exe",
    }
  ]
}
/**
 * Cập nhật dữ liệu phiên bản cho Node.js
 */
async function fetchNodejsVersions() {
  try {
    const response = await fetch('https://nodejs.org/download/release/index.json');
    if (!response.ok) throw new Error('Network response was not ok');
    
    const data = await response.json();
    const versions = {};
    
    data.filter(v => {
      const major = parseInt(v.version.replace('v', '').split('.')[0]);
      return major >= 4;
    }).forEach(v => {
      const ver = v.version.replace('v', '');
      versions[ver] = `https://nodejs.org/dist/v${ver}/node-v${ver}-win-x64.zip`;
    });
    
    return versions;
  } catch (error) {
    console.error('Error fetching Node.js versions:', error);
    return null;
  }
}

/**
 * Cập nhật dữ liệu phiên bản cho PHP từ archives của php.net
 */
async function fetchPhpVersions(versionPrefix) {
  try {
    const baseUrl = 'https://downloads.php.net/~windows/releases/archives/';
    const response = await fetch(baseUrl);
    if (!response.ok) return null;
    
    const html = await response.text();
    const versions = {};
    
    // Regex tìm file zip NTS cho Windows x64
    // Ví dụ: php-8.2.1-nts-Win32-vs16-x64.zip
    const regex = new RegExp(`php-(${versionPrefix}\\.\\d+)-nts-Win32-.*?-x64\\.zip`, 'gi');
    const matches = html.matchAll(regex);
    
    for (const match of matches) {
      const fileName = match[0];
      const ver = match[1];
      versions[ver] = baseUrl + fileName;
    }
    
    return versions;
  } catch (error) {
    console.error(`Error fetching PHP ${versionPrefix} versions:`, error);
    return null;
  }
}

/**
 * Cập nhật dữ liệu phiên bản cho MySQL từ Docker Hub
 */
async function fetchMysqlVersions() {
  const regex = /^(\d+\.\d+\.\d+)$/; // Chỉ lấy phiên bản X.Y.Z
  try {
    const versions = {};
    for (let page = 1; page <= 5; page++) {
      const url = `https://hub.docker.com/v2/namespaces/library/repositories/mysql/tags?page=${page}&page_size=100`;
      const response = await fetch(url);
      if (!response.ok) break;
      
      const data = await response.json();
      if (!data.results) break;
      
      data.results.forEach(tag => {
        if (regex.test(tag.name)) {
          const ver = tag.name;
          const majorMinor = ver.split('.').slice(0, 2).join('.');
          versions[ver] = `https://cdn.mysql.com/Downloads/MySQL-${majorMinor}/mysql-${ver}-winx64.zip`;
        }
      });
    }
    
    return versions;
  } catch (error) {
    console.error('Error fetching MySQL versions:', error);
    return null;
  }
}

/**
 * Cập nhật dữ liệu phiên bản cho MariaDB từ MariaDB REST API
 */
async function fetchMariadbVersions() {
  try {
    const response = await fetch('https://downloads.mariadb.org/rest-api/mariadb/');
    if (!response.ok) return null;
    
    const data = await response.json();
    if (!data.major_releases) return {};
    
    const versions = {};
    data.major_releases.forEach(r => {
      const ver = r.release_id;
      versions[ver] = `https://mirror.mariadb.org/mariadb-${ver}/winx64-packages/mariadb-${ver}-winx64.zip`;
    });
    
    return versions;
  } catch (error) {
    console.error('Error fetching MariaDB versions:', error);
    return null;
  }
}

/**
 * Lấy danh sách phiên bản từ Github Releases
 */
/**
 * Lấy danh sách phiên bản từ Github Releases
 */
async function fetchGithubReleases(repoPath) {
  try {
    const url = `https://api.github.com/repos/${repoPath}/releases`;
    const response = await fetch(url, {
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'Ponta-Update-Script'
      }
    });
    if (!response.ok) return null;
    
    const data = await response.json();
    if (!Array.isArray(data)) return {};
    
    const versions = {};
    data.forEach(r => {
      const ver = r.tag_name.replace(/^(v|release-|redis-|redis|r(?=\d))/i, '');
      
      // Tìm asset phù hợp (ưu tiên có 'win', sau đó là bất kỳ zip/msi nào)
      let downloadUrl = `https://github.com/${repoPath}/archive/refs/tags/${r.tag_name}.zip`; // Fallback mặc định là source zip
      
      if (r.assets && r.assets.length > 0) {
        // Ưu tiên 1: Có 'win' và là zip/msi
        let winAsset = r.assets.find(a => 
          (a.name.toLowerCase().includes('win') || a.name.toLowerCase().includes('x64')) && 
          (a.name.toLowerCase().endsWith('.zip') || a.name.toLowerCase().endsWith('.msi'))
        );
        
        // Ưu tiên 2: Bất kỳ file zip/msi nào
        if (!winAsset) {
          winAsset = r.assets.find(a => 
            a.name.toLowerCase().endsWith('.zip') || 
            a.name.toLowerCase().endsWith('.msi')
          );
        }
        
        if (winAsset) downloadUrl = winAsset.browser_download_url;
      }
      
      versions[ver] = downloadUrl;
    });
    
    return versions;
  } catch (error) {
    console.error(`Error fetching Github releases for ${repoPath}:`, error);
    return null;
  }
}

/**
 * Lấy danh sách phiên bản MongoDB từ downloads.mongodb.org
 */
async function fetchMongodbVersions() {
  try {
    const url = 'https://downloads.mongodb.org/current.json';
    const response = await fetch(url);
    if (!response.ok) return null;
    
    const json = await response.json();
    const versions = {};

    if (json.versions) {
      json.versions.forEach(v => {
        // Bỏ các bản pre-release (rc, alpha, beta)
        if (v.version.match(/-(rc|alpha|beta)/i)) return;

        // Tìm bản download cho Windows x86_64 Community (base)
        const winAsset = v.downloads?.find(d => 
          d.target === 'windows' && 
          d.arch === 'x86_64' && 
          d.edition === 'base'
        );

        if (winAsset?.archive) {
          versions[v.version] = winAsset.archive.url;
        }
      });
    }

    return versions;
  } catch (error) {
    console.error('Error fetching MongoDB versions:', error);
    return null;
  }
}

/**
 * Lấy danh sách phiên bản Apache từ ApacheLounge (Parsing HTML)
 */
async function fetchApacheVersions() {
  try {
    const response = await fetch('https://www.apachelounge.com/download/');
    if (!response.ok) return null;
    
    const html = await response.text();
    
    // Sử dụng regex giới hạn trong thẻ href để tránh bắt nhầm text bên ngoài
    const regex = /href="([^"]*?\/binaries\/httpd-([\d.]+)-[\d]+-win64-.*?\.zip)"/gi;
    const matches = html.matchAll(regex);
    const versions = {};
    
    for (const match of matches) {
      const path = match[1];
      const ver = match[2];
      // Nếu là đường dẫn tương đối, thêm domain vào
      const fullUrl = path.startsWith('http') ? path : `https://www.apachelounge.com${path}`;
      versions[ver] = fullUrl;
    }
    
    return versions;
  } catch (error) {
    console.error('Error fetching Apache versions:', error);
    return null;
  }
}

/**
 * Hàm chính thực hiện cập nhật apps.json
 */
async function updateAppsJson() {
  const filePath = path.join(__dirname, 'new-apps.json');
  try {
    // 1. Cập nhật Node.js 
    const nodeApp = baseDataObject.apps.find(app => app.id === 'nodejs');
    if (nodeApp) {
      const newVersions = await fetchNodejsVersions();
      if (newVersions) {
        nodeApp.versions = sortVersionsObject(newVersions);
        console.log(`Updated Node.js: ${Object.keys(nodeApp.versions).length} versions`);
      }
    }

    // 2. Cập nhật PHP
    const phpApps = baseDataObject.apps.filter(app => app.id.startsWith('php'));
    for (const app of phpApps) {
      const versionPrefix = app.name.split(' ')[1];
      if (versionPrefix) {
        const newVersions = await fetchPhpVersions(versionPrefix);
        if (newVersions) {
          // Merge hoặc replace
          app.versions = sortVersionsObject(newVersions);
          console.log(`Updated ${app.name}: ${Object.keys(app.versions)[0]}`);
        }
      }
    }

    // 3. Cập nhật MySQL
    const mysqlApp = baseDataObject.apps.find(app => app.id === 'mysql');
    if (mysqlApp) {
      const newVersions = await fetchMysqlVersions();
      if (newVersions) {
        mysqlApp.versions = sortVersionsObject(newVersions);
        console.log(`Updated MySQL: ${Object.keys(mysqlApp.versions).length} versions`);
      }
    }

    // 4. Cập nhật MariaDB
    const mariadbApp = baseDataObject.apps.find(app => app.id === 'mariadb');
    if (mariadbApp) {
      const newVersions = await fetchMariadbVersions();
      if (newVersions) {
        mariadbApp.versions = sortVersionsObject(newVersions);
        console.log(`Updated MariaDB: ${Object.keys(mariadbApp.versions).length} versions`);
      }
    }

    // 5. Cập nhật Nginx
    const nginxApp = baseDataObject.apps.find(app => app.id === 'nginx');
    if (nginxApp) {
      const newVersions = await fetchGithubReleases('nginx/nginx');
      if (newVersions) {
        nginxApp.versions = sortVersionsObject(newVersions);
        console.log(`Updated Nginx: ${Object.keys(nginxApp.versions).length} versions`);
      }
    }

    // 6. Cập nhật Apache
    const apacheApp = baseDataObject.apps.find(app => app.id === 'apache');
    if (apacheApp) {
      const newVersions = await fetchApacheVersions();
      if (newVersions) {
        apacheApp.versions = sortVersionsObject(newVersions);
        console.log(`Updated Apache: ${Object.keys(apacheApp.versions).length} versions`);
      }
    }

    // 7. Cập nhật Redis
    const redisApp = baseDataObject.apps.find(app => app.id === 'redis');
    if (redisApp) {
      const newVersions = await fetchGithubReleases('zkteco-home/redis-windows');
      if (newVersions) {
        redisApp.versions = sortVersionsObject(newVersions);
        console.log(`Updated Redis: ${Object.keys(redisApp.versions).length} versions`);
      }
    }

    // 8. Cập nhật MongoDB
    const mongodbApp = baseDataObject.apps.find(app => app.id === 'mongodb');
    if (mongodbApp) {
      const newVersions = await fetchMongodbVersions();
      if (newVersions) {
        mongodbApp.versions = sortVersionsObject(newVersions);
        console.log(`Updated MongoDB: ${Object.keys(mongodbApp.versions).length} versions`);
      }
    }

    // 9. Cập nhật thời gian
    baseDataObject.lastUpdated = new Date().toISOString();
    
    // Ghi lại file
    await fs.writeFile(filePath, JSON.stringify(baseDataObject, null, 2), 'utf8');
    console.log(`[${new Date().toLocaleString()}] Cập nhật apps.json hoàn tất.`);
  } catch (error) {
    console.error('Lỗi khi cập nhật apps.json:', error);
  }
}

// Chạy lần đầu tiên khi start
updateAppsJson();