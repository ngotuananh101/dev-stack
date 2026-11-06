const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const repo = 'ngotuananh101/devstack-app-builder';
const api = `https://api.github.com/repos/${repo}/releases?per_page=100&page=`;
const digest = 'a'.repeat(64);

function asset(version, variant = 'glibc-full-x86_64', build = 'abcdef0123456789') {
  const name = `php-${version}-${variant}-${build}.tar.gz`;
  return {
    name,
    browser_download_url: `https://github.com/${repo}/releases/download/runtime-1/${name}`,
    digest: `sha256:${digest}`,
  };
}

function updater(fetch, dataDir = path.resolve('assets/data')) {
  const context = vm.createContext({
    require, module: { exports: {} }, process: { env: {} },
    __dirname: dataDir, structuredClone, fetch,
    console: { log() {}, error() {}, warn() {} }, URL,
  });
  // The guarded CLI entrypoint does not run when loaded for offline tests.
  const source = fs.readFileSync('assets/data/update.js', 'utf8');
  vm.runInContext(source, context);
  return vm.runInContext('({ fetchersLinux, createLinuxPhpApps, applyFetchedVersions, applyFallbackVersions, baseLinuxApps, baseWindowsApps, updatePlatformCatalog })', context);
}

function response(data, { status = 200, next } = {}) {
  return {
    ok: status >= 200 && status < 300, status,
    headers: { get: (name) => name.toLowerCase() === 'link' && next ? `<${next}>; rel="next"` : null },
    json: async () => data,
  };
}

const plain = (value) => JSON.parse(JSON.stringify(value));

test('all Linux definitions omit package installation metadata', () => {
  const { baseLinuxApps } = updater(async () => response([]));
  for (const app of baseLinuxApps) {
    assert.notEqual(app.install_method, 'package_manager');
    assert.equal(app.package_manager_commands, undefined);
  }
  for (const id of ['apache', 'redis', 'postgresql']) {
    assert.deepEqual(plain(baseLinuxApps.find((app) => app.id === id).versions), {});
  }
});

for (const platform of ['Linux', 'Windows']) {
  test(`${platform} generated catalog includes required app display metadata`, async (t) => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'updater-metadata-'));
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const u = updater(async () => { throw Error('Unexpected network request'); }, dir);
    await u.updatePlatformCatalog({
      platformName: platform,
      baseApps: platform === 'Linux' ? u.baseLinuxApps : u.baseWindowsApps,
      fetchers: {},
      outputFileName: 'output.json',
      existingFileName: 'absent.json',
    });
    const catalog = JSON.parse(fs.readFileSync(path.join(dir, 'output.json'), 'utf8'));
    assert.ok(catalog.apps.length > 0);
    for (const app of catalog.apps) {
      assert.equal(typeof app.id, 'string');
      assert.ok(app.id.trim(), 'App ID must not be empty');
      assert.equal(typeof app.name, 'string', `Missing display name for ${app.id}`);
      assert.ok(app.name.trim(), `Empty display name for ${app.id}`);
    }
    const redis = catalog.apps.find((app) => app.id === 'redis');
    assert.equal(redis.name, 'Redis');
    assert.equal(typeof redis.description, 'string');
    assert.ok(redis.description.trim());
  });
}

for (const [platform, expectedVersions] of [
  ['Linux', {}],
  ['Windows', { '1.2.3': 'https://example.com/source.tar.gz' }],
]) {
  test(`${platform} output catalog respects unavailable runtimes after fallback`, async (t) => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'updater-fallback-'));
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const u = updater(async () => { throw Error('Unexpected network request'); }, dir);
    const ids = ['apache', 'redis', 'postgresql'];
    const definitions = platform === 'Linux' ? u.baseLinuxApps : u.baseWindowsApps;
    const apps = definitions.filter((app) => ids.includes(app.id));
    const oldData = {
      apps: ids.map((id) => ({ id, versions: {
        '1.2.3': 'https://example.com/source.tar.gz',
        latest: 'package_manager',
      } })),
    };
    fs.writeFileSync(path.join(dir, 'existing.json'), JSON.stringify(oldData));
    await u.updatePlatformCatalog({
      platformName: platform,
      baseApps: apps,
      fetchers: {},
      outputFileName: 'output.json',
      existingFileName: 'existing.json',
    });
    const catalog = JSON.parse(fs.readFileSync(path.join(dir, 'output.json'), 'utf8'));
    assert.deepEqual(catalog.apps.map((app) => app.id), ids);
    for (const app of catalog.apps) assert.deepEqual(app.versions, expectedVersions);
  });
}

test('discovers all PHP patches across pages once for all minors', async () => {
  const calls = [];
  const a = asset('8.4.27');
  const b = asset('8.4.26');
  const c = asset('8.5.1');
  const u = updater(async (url) => {
    calls.push(url);
    if (url === api + '1') return response([{ assets: [a] }], { next: api + '2' });
    if (url === api + '2') return response([{ assets: [b, c] }]);
    throw Error(`Unexpected request: ${url}`);
  });
  const [php84, php85] = await Promise.all([u.fetchersLinux.php('8.4'), u.fetchersLinux.php('8.5')]);
  assert.deepEqual(plain(php84.versions), { '8.4.27': a.browser_download_url, '8.4.26': b.browser_download_url });
  assert.deepEqual(plain(php84.sha256), { '8.4.27': digest, '8.4.26': digest });
  assert.deepEqual(plain(php85.versions), { '8.5.1': c.browser_download_url });
  assert.deepEqual(calls, [api + '1', api + '2']);
});

test('skips non-portable assets and draft/prerelease builds', async () => {
  const good = asset('8.4.27');
  const u = updater(async () => response([
    { draft: true, assets: [asset('8.4.29')] },
    { prerelease: true, assets: [asset('8.4.28')] },
    { assets: [good, asset('8.4.30', 'musl-full-x86_64'), asset('8.4.31', 'glibc-minimal-x86_64'), asset('8.4.32', 'glibc-full-aarch64'), { name: 'php-8.4.33.tar.gz', browser_download_url: 'https://example.com/source.tar.gz' }] },
  ]));
  assert.deepEqual(plain((await u.fetchersLinux.php('8.4')).versions), { '8.4.27': good.browser_download_url });
});

test('prefers newest release build and does not attach an invalid digest', async () => {
  const newest = { ...asset('8.4.27', undefined, 'bbbbbbbbbbbbbbbb'), digest: 'sha256:bad' };
  const u = updater(async () => response([{ assets: [newest] }, { assets: [asset('8.4.27')] }]));
  const result = await u.fetchersLinux.php('8.4');
  assert.deepEqual(plain(result.versions), { '8.4.27': newest.browser_download_url });
  assert.deepEqual(plain(result.sha256), {});
});

for (const [label, res] of [
  ['HTTP rate limit', response({ message: 'rate limit' }, { status: 403 })],
  ['malformed response', response({ message: 'not an array' })],
]) {
  test(`does not treat ${label} as an empty successful catalog`, async () => {
    const u = updater(async () => res);
    await assert.rejects(() => u.fetchersLinux.php('8.4'));
  });
}

test('Linux PHP definitions select archive installation without PM fallback', () => {
  const u = updater(async () => response([]));
  const [app] = u.createLinuxPhpApps(['8.4']);
  assert.equal(app.install_method, undefined);
  assert.equal(app.package_manager_commands, undefined);
  assert.equal(app.exec_file, 'php-fpm');
  assert.equal(app.cli_file, 'php');
  assert.deepEqual(plain(app.versions), {});
});

test('application keeps every fetched PHP patch and matching checksums', () => {
  const u = updater(async () => response([]));
  const [app] = u.createLinuxPhpApps(['8.4']);
  const a = asset('8.4.27');
  const b = asset('8.4.26');
  u.applyFetchedVersions(app, { versions: { '8.4.26': b.browser_download_url, '8.4.27': a.browser_download_url }, sha256: { '8.4.27': digest } });
  assert.deepEqual(plain(app.versions), { '8.4.27': a.browser_download_url, '8.4.26': b.browser_download_url });
  assert.deepEqual(plain(app.sha256), { '8.4.27': digest });
});

test('failed fetch preserves only compatible old URLs with their checksums', () => {
  const u = updater(async () => response([]));
  const [app] = u.createLinuxPhpApps(['8.4']);
  const a = asset('8.4.27');
  const old = { apps: [{ id: 'php84', versions: { '8.4': 'package_manager', '8.4.27': a.browser_download_url, '8.4.26': 'https://example.com/source.tar.gz' }, sha256: { '8.4.27': digest } }] };
  u.applyFallbackVersions(app, old, null);
  assert.deepEqual(plain(app.versions), { '8.4.27': a.browser_download_url });
  assert.deepEqual(plain(app.sha256), { '8.4.27': digest });
});

test('successful empty discovery does not resurrect old bundle URLs', () => {
  const u = updater(async () => response([]));
  const [app] = u.createLinuxPhpApps(['8.4']);
  const result = { versions: {}, sha256: {} };
  u.applyFetchedVersions(app, result);
  u.applyFallbackVersions(app, { apps: [{ id: 'php84', versions: { '8.4.27': asset('8.4.27').browser_download_url } }] }, result);
  assert.deepEqual(plain(app.versions), {});
});
