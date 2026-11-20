const { readFileSync } = require('node:fs');

const [windowsPath, linuxPath] = process.argv.slice(2);
const windows = readFileSync(windowsPath, 'utf8');
const linux = readFileSync(linuxPath, 'utf8');
const catalog = JSON.parse(linux);
const legacy = {
  ...catalog,
  apps: catalog.apps.filter((app) => app.id !== 'mongodb-compass'),
};

process.stdout.write(JSON.stringify({
  files: {
    'apps.json': { content: windows },
    'apps-linux.json': { content: JSON.stringify(legacy, null, 2) + '\n' },
    'apps-linux-v2.json': { content: linux },
  },
}));
