const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

const script = path.resolve(__dirname, '../../assets/data/gist-catalog-payload.cjs');

test('Gist payload keeps Compass out of the legacy Linux feed only', (t) => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'devstack-gist-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const windowsFile = path.join(dir, 'windows.json');
  const linuxFile = path.join(dir, 'linux.json');
  const windows = JSON.stringify({ apps: [{ id: 'mongodb-compass', exec_file: 'MongoDBCompass.exe' }] });
  const redis = { id: 'redis', versions: { '8.0.0': 'https://example.test/redis.tar.gz' } };
  const compass = { id: 'mongodb-compass', exec_file: 'MongoDB Compass' };
  const linux = { version: 'test', apps: [compass, redis] };
  const full = JSON.stringify(linux, null, 2) + '\n';
  fs.writeFileSync(windowsFile, windows);
  fs.writeFileSync(linuxFile, full);

  const { files } = JSON.parse(execFileSync(process.execPath, [script, windowsFile, linuxFile], { encoding: 'utf8' }));
  assert.deepEqual(Object.keys(files).sort(), ['apps-linux-v2.json', 'apps-linux.json', 'apps.json']);
  assert.equal(files['apps.json'].content, windows);
  assert.equal(files['apps-linux-v2.json'].content, full);
  assert.deepEqual(JSON.parse(files['apps-linux.json'].content), { ...linux, apps: [redis] });
  assert.equal(fs.readFileSync(linuxFile, 'utf8'), full);
});
