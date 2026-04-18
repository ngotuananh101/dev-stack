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
      }
    }
    // 2. Cập nhật thời gian
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