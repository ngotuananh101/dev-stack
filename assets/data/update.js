const fs = require('fs').promises;
const path = require('path');

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
      id: "php74",
      name: "PHP 7.4",
      description: "Hypertext Preprocessor v7.4",
      category: "runtime",
      group_name: "php",
      exec_file: "php.exe",
      cli_file: "php.exe",
    },
    {
      id: "php81",
      name: "PHP 8.1",
      description: "Hypertext Preprocessor v8.1",
      category: "runtime",
      group_name: "php",
      exec_file: "php.exe",
      cli_file: "php.exe",
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
    
    // Lọc các phiên bản từ v4.0.0 trở lên
    const versions = data
      .filter(v => {
        const major = parseInt(v.version.replace('v', '').split('.')[0]);
        return major >= 4;
      })
      .map(v => v.version.replace('v', ''));
    
    return versions;
  } catch (error) {
    console.error('Error fetching Node.js versions:', error);
    return null;
  }
}

/**
 * Cập nhật dữ liệu phiên bản cho PHP từ php.net
 */
async function fetchPhpVersions(versionPrefix) {
  try {
    const url = `https://www.php.net/releases/index.php?json&version=${versionPrefix}`;
    const response = await fetch(url);
    if (!response.ok) return null;
    
    const data = await response.json();
    return data.version ? [data.version] : [];
  } catch (error) {
    console.error(`Error fetching PHP ${versionPrefix} versions:`, error);
    return null;
  }
}

/**
 * Cập nhật dữ liệu phiên bản cho MySQL từ Docker Hub
 */
async function fetchMysqlVersions() {
  const allVersions = [];
  const regex = /^(\d+\.\d+\.\d+)$/; // Chỉ lấy phiên bản X.Y.Z
  
  try {
    for (let page = 1; page <= 5; page++) {
      const url = `https://hub.docker.com/v2/namespaces/library/repositories/mysql/tags?page=${page}&page_size=100`;
      const response = await fetch(url);
      if (!response.ok) break;
      
      const data = await response.json();
      if (!data.results) break;
      
      const versions = data.results
        .map(t => t.name)
        .filter(name => regex.test(name));
        
      allVersions.push(...versions);
    }
    
    // Xóa trùng và sắp xếp giảm dần
    return [...new Set(allVersions)].sort((a, b) => {
      const partsA = a.split('.').map(Number);
      const partsB = b.split('.').map(Number);
      for (let i = 0; i < 3; i++) {
        if (partsA[i] > partsB[i]) return -1;
        if (partsA[i] < partsB[i]) return 1;
      }
      return 0;
    });
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
    if (!data.major_releases) return [];
    
    // Lấy tất cả release_id từ danh sách các bản phát hành lớn
    return data.major_releases.map(r => r.release_id);
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
    if (!Array.isArray(data)) return [];
    
    // Lấy tag_name và làm sạch (bỏ v hoặc release-)
    return data.map(r => r.tag_name.replace('release-', '').replace('v', ''));
  } catch (error) {
    console.error(`Error fetching Github releases for ${repoPath}:`, error);
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
    
    // Sử dụng regex linh hoạt hơn để bắt cả đường dẫn tương đối và tuyệt đối
    // Tập trung vào thư mục /binaries/ để lấy đúng bộ cài Apache Core
    const regex = /(?:https:\/\/www\.apachelounge\.com)?\/download\/.*?\/binaries\/httpd-([\d.]+)-[\d]+-win64-.*?\.zip/gi;
    const matches = html.matchAll(regex);
    const versions = [];
    
    for (const match of matches) {
      versions.push(match[1]); // Lấy group 1 là phiên bản X.Y.Z
    }
    
    // Xóa trùng và sắp xếp giảm dần
    return [...new Set(versions)].sort((a, b) => {
      const partsA = a.split('.').map(Number);
      const partsB = b.split('.').map(Number);
      for (let i = 0; i < 3; i++) {
        if (partsA[i] > partsB[i]) return -1;
        if (partsA[i] < partsB[i]) return 1;
      }
      return 0;
    });
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
        nodeApp.versions = newVersions;
        console.log(`Updated ${newVersions.length} Node.js versions`);
      }
    }

    // 2. Cập nhật PHP
    const phpApps = baseDataObject.apps.filter(app => app.id.startsWith('php'));
    for (const app of phpApps) {
      // Lấy prefix từ name (e.g., "PHP 8.2" -> "8.2")
      const versionPrefix = app.name.split(' ')[1];
      if (versionPrefix) {
        const newVersions = await fetchPhpVersions(versionPrefix);
        if (newVersions) {
          app.versions = newVersions;
          console.log(`Updated ${app.name}:`, newVersions.slice(0, 3).join(', '), '...');
        }
      }
    }

    // 3. Cập nhật MySQL
    const mysqlApp = baseDataObject.apps.find(app => app.id === 'mysql');
    if (mysqlApp) {
      const newVersions = await fetchMysqlVersions();
      if (newVersions) {
        mysqlApp.versions = newVersions;
        console.log(`Updated MySQL: ${newVersions.length} versions found`);
      }
    }

    // 4. Cập nhật MariaDB
    const mariadbApp = baseDataObject.apps.find(app => app.id === 'mariadb');
    if (mariadbApp) {
      const newVersions = await fetchMariadbVersions();
      if (newVersions) {
        mariadbApp.versions = newVersions;
        console.log(`Updated MariaDB: ${newVersions.length} versions found`);
      }
    }

    // 5. Cập nhật Nginx từ Github Releases
    const nginxApp = baseDataObject.apps.find(app => app.id === 'nginx');
    if (nginxApp) {
      const newVersions = await fetchGithubReleases('nginx/nginx');
      if (newVersions) {
        nginxApp.versions = newVersions;
        console.log(`Updated Nginx: ${newVersions.length} versions found`);
      }
    }

    // 6. Cập nhật Apache từ ApacheLounge
    const apacheApp = baseDataObject.apps.find(app => app.id === 'apache');
    if (apacheApp) {
      const newVersions = await fetchApacheVersions();
      if (newVersions) {
        apacheApp.versions = newVersions;
        console.log(`Updated Apache: ${newVersions.length} versions found`);
      }
    }

    // 7. Cập nhật thời gian
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