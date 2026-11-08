"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const {
  apacheAsset,
  apiOrigin,
  assetsApi,
  digest,
  fixtureDir,
  githubNetwork,
  loadUpdater,
  phpAsset,
  plain,
  postgresqlAsset,
  redisAsset,
  release,
  releasesApi,
  repo,
  response,
} = require("./updater_test_helpers.cjs");

test("newest Redis-only release keeps PHP patches from older release pages", async (t) => {
  const php84 = phpAsset("8.4.27", { tag: "runtimes-2026-11-04" });
  const php85 = phpAsset("8.5.1", { tag: "runtimes-2026-11-05" });
  const redis = redisAsset("8.10.3", { tag: "runtimes-2026-11-06" });
  const network = githubNetwork({
    releasePages: [
      [release(3, { tag: "runtimes-2026-11-06" })],
      [release(2, { tag: "runtimes-2026-11-05" }), release(1, { tag: "runtimes-2026-11-04" })],
    ],
    assetsByRelease: { 3: [redis], 2: [php85], 1: [php84] },
  });
  const u = loadUpdater(network.fetch, fixtureDir(t));

  const [r84, r85, rRedis] = await Promise.all([
    u.fetchersLinux.php("8.4"),
    u.fetchersLinux.php("8.5"),
    u.fetchersLinux.redis(),
  ]);

  assert.deepEqual(plain(r84.versions), { "8.4.27": php84.browser_download_url });
  assert.deepEqual(plain(r85.versions), { "8.5.1": php85.browser_download_url });
  assert.deepEqual(plain(rRedis.versions), { "8.10.3": redis.browser_download_url });
  assert.deepEqual(plain(rRedis.sha256), { "8.10.3": digest });
  // One shared scan: release page 1 and 2 plus one asset page per release.
  assert.deepEqual(network.calls, [
    releasesApi + "1",
    releasesApi + "2",
    assetsApi("3") + "1",
    assetsApi("2") + "1",
    assetsApi("1") + "1",
  ]);
});

test("release assets beyond the embedded list are discovered by pagination", async (t) => {
  const first = phpAsset("8.4.27", { tag: "runtimes-2026-11-01" });
  const second = phpAsset("8.4.26", { tag: "runtimes-2026-11-01" });
  const third = redisAsset("7.4.12", { tag: "runtimes-2026-11-01" });
  const network = githubNetwork({
    releasePages: [[release(7, { tag: "runtimes-2026-11-01" })]],
    assetsByRelease: { 7: [[first, second], [third]] },
  });
  const u = loadUpdater(network.fetch, fixtureDir(t));

  const [php84, redis] = await Promise.all([u.fetchersLinux.php("8.4"), u.fetchersLinux.redis()]);
  assert.deepEqual(plain(php84.versions), {
    "8.4.27": first.browser_download_url,
    "8.4.26": second.browser_download_url,
  });
  assert.deepEqual(plain(redis.versions), { "7.4.12": third.browser_download_url });
  assert.deepEqual(network.calls, [
    releasesApi + "1",
    assetsApi("7") + "1",
    assetsApi("7") + "2",
  ]);
});

test("Redis keeps every supported patch and prefers the newest build per version", async (t) => {
  const newest = redisAsset("8.10.3", {
    tag: "runtimes-2026-11-06",
    build: "bbbbbbbbbbbbbbbb",
    hash: "b".repeat(64),
  });
  const older = redisAsset("8.10.3", { tag: "runtimes-2026-11-01" });
  const otherPatch = redisAsset("7.2.17", { tag: "runtimes-2026-10-30" });
  const network = githubNetwork({
    releasePages: [
      [release(9, { tag: "runtimes-2026-11-06" })],
      [release(8, { tag: "runtimes-2026-11-01" }), release(6, { tag: "runtimes-2026-10-30" })],
    ],
    assetsByRelease: { 9: [newest], 8: [older], 6: [otherPatch] },
  });
  const u = loadUpdater(network.fetch, fixtureDir(t));

  const redis = await u.fetchersLinux.redis();
  assert.deepEqual(plain(redis.versions), {
    "8.10.3": newest.browser_download_url,
    "7.2.17": otherPatch.browser_download_url,
  });
  assert.deepEqual(plain(redis.sha256), {
    "8.10.3": "b".repeat(64),
    "7.2.17": digest,
  });
});

test("Redis ignores unsupported targets, source archives and draft/prerelease builds", async (t) => {
  const musl = redisAsset("8.10.3", { hash: digest });
  const network = githubNetwork({
    releasePages: [
      [
        release(5, {
          tag: "runtimes-2026-11-06",
          draft: true,
          assets: [],
        }),
      ],
      [
        release(4, { tag: "runtimes-2026-11-05", prerelease: true }),
        release(1, { tag: "runtimes-2026-11-04" }),
      ],
    ],
    assetsByRelease: {
      5: [redisAsset("9.9.9")],
      4: [redisAsset("9.9.8")],
      1: [
        musl,
        redisAsset("8.10.4", { target: "glibc" }),
        redisAsset("8.10.5", { name: "redis-8.10.5-musl-aarch64-abcdef0123456789.tar.gz" }),
        redisAsset("8.10.6", { name: "redis-8.10.6-musl-x86_64.tar.gz" }),
        { name: "redis-8.10.7.tar.gz", browser_download_url: "https://download.redis.io/releases/redis-8.10.7.tar.gz" },
      ],
    },
  });
  const u = loadUpdater(network.fetch, fixtureDir(t));

  assert.deepEqual(plain((await u.fetchersLinux.redis()).versions), {
    "8.10.3": musl.browser_download_url,
  });
});

test("an asset whose URL basename disagrees with its name is rejected", async (t) => {
  const honest = redisAsset("8.10.3");
  const mismatched = redisAsset("7.4.12", {
    url: `https://github.com/ngotuananh101/devstack-app-builder/releases/download/runtimes-2026-11-06/redis-8.10.3-musl-x86_64-abcdef0123456789.tar.gz`,
  });
  const foreignHost = redisAsset("7.2.17", {
    url: "https://example.com/redis-7.2.17-musl-x86_64-abcdef0123456789.tar.gz",
  });
  const network = githubNetwork({
    releasePages: [[release(1)]],
    assetsByRelease: { 1: [honest, mismatched, foreignHost] },
  });
  const u = loadUpdater(network.fetch, fixtureDir(t));

  assert.deepEqual(plain((await u.fetchersLinux.redis()).versions), {
    "8.10.3": honest.browser_download_url,
  });
});

for (const [runtime, makeAsset, fetchRuntime] of [
  ["PHP", phpAsset, (u) => u.fetchersLinux.php("8.4")],
  ["Redis", redisAsset, (u) => u.fetchersLinux.redis()],
]) {
  test(`${runtime} rejects a URL for a different build of the same version`, async (t) => {
    const version = runtime === "PHP" ? "8.4.27" : "8.10.3";
    const wrongBuild = makeAsset(version, { build: "bbbbbbbbbbbbbbbb" });
    const mismatched = makeAsset(version, {
      build: "aaaaaaaaaaaaaaaa",
      url: wrongBuild.browser_download_url,
    });
    const network = githubNetwork({
      releasePages: [[release(1)]],
      assetsByRelease: { 1: [mismatched] },
    });
    const u = loadUpdater(network.fetch, fixtureDir(t));

    // The URL points to a different build, so neither its URL nor the digest
    // of the named asset may become installable catalog data.
    assert.deepEqual(plain(await fetchRuntime(u)), { versions: {}, sha256: {} });
  });
}

test("successful Redis discovery of nothing leaves Redis unavailable", async (t) => {
  const network = githubNetwork({
    releasePages: [[release(1)]],
    assetsByRelease: { 1: [] },
  });
  const u = loadUpdater(network.fetch, fixtureDir(t));

  assert.deepEqual(plain(await u.fetchersLinux.redis()), { versions: {}, sha256: {} });
});

test("the Linux catalog installs Redis from discovered builder bundles", async (t) => {
  const dir = fixtureDir(t);
  const redis = redisAsset("8.10.3");
  const network = githubNetwork({
    releasePages: [[release(1)]],
    assetsByRelease: { 1: [redis] },
  });
  const u = loadUpdater(network.fetch, dir);

  await u.updatePlatformCatalog({
    platformName: "Linux",
    baseApps: u.baseLinuxApps.filter((app) => app.id === "redis"),
    fetchers: u.fetchersLinux,
    outputFileName: "new-apps-linux.json",
    existingFileName: "apps-linux.json",
  });

  const catalog = JSON.parse(fs.readFileSync(path.join(dir, "new-apps-linux.json"), "utf8"));
  const [app] = catalog.apps;
  assert.deepEqual(plain(app.versions), { "8.10.3": redis.browser_download_url });
  assert.deepEqual(plain(app.sha256), { "8.10.3": digest });
  assert.equal(app.exec_file, "redis-server");
  assert.equal(app.cli_file, "redis-cli");
  assert.equal(app.install_method, undefined);
});

test("Redis fallback restores only builder-owned bundles with matching checksums", async (t) => {
  const dir = fixtureDir(t);
  const good = redisAsset("8.10.3");
  const oldData = {
    apps: [
      {
        id: "redis",
        versions: {
          "8.10.3": good.browser_download_url,
          "8.10.4": "https://example.com/redis-8.10.4-musl-x86_64-abcdef0123456789.tar.gz",
          "8.10.5": "https://github.com/ngotuananh101/devstack-app-builder/releases/download/runtimes/redis-8.10.5-glibc-x86_64-abcdef0123456789.tar.gz",
          latest: "package_manager",
        },
        sha256: { "8.10.3": digest, "8.10.4": digest },
      },
    ],
  };
  fs.writeFileSync(path.join(dir, "apps-linux.json"), JSON.stringify(oldData));
  const u = loadUpdater(
    async () => {
      throw new Error("Unexpected network request");
    },
    dir,
  );
  const app = u.baseLinuxApps.find((entry) => entry.id === "redis");
  app.versions = {};

  u.applyFallbackVersions(app, oldData, null, "Linux");

  assert.deepEqual(plain(app.versions), { "8.10.3": good.browser_download_url });
  assert.deepEqual(plain(app.sha256), { "8.10.3": digest });
});

// --- Task 2: an incomplete builder scan must not become a published catalog ---

test("a release-page HTTP failure rejects the whole catalog update", async (t) => {
  const dir = fixtureDir(t);
  const redis = redisAsset("8.10.3");
  const network = githubNetwork({
    releasePages: [[release(1)], [release(2)]],
    assetsByRelease: { 1: [redis] },
    override: (url) =>
      url === releasesApi + "2" ? response({ message: "rate limit" }, { status: 403 }) : null,
  });
  const u = loadUpdater(network.fetch, dir);

  await assert.rejects(
    () =>
      u.updatePlatformCatalog({
        platformName: "Linux",
        baseApps: u.baseLinuxApps,
        fetchers: u.fetchersLinux,
        outputFileName: "new-apps-linux.json",
        existingFileName: "apps-linux.json",
      }),
    /403/,
  );
  assert.equal(fs.existsSync(path.join(dir, "new-apps-linux.json")), false);
});

for (const [label, makeResponse] of [
  ["malformed release page", () => response({ message: "not an array" })],
  ["release entry without a usable id", () => response([{ tag_name: "runtimes-1" }])],
  ["release entry that is not an object", () => response([null])],
]) {
  test(`a ${label} aborts instead of publishing a partial catalog`, async (t) => {
    const dir = fixtureDir(t);
    const u = loadUpdater(githubNetwork({ override: () => makeResponse() }).fetch, dir);

    await assert.rejects(() =>
      u.updatePlatformCatalog({
        platformName: "Linux",
        baseApps: u.baseLinuxApps,
        fetchers: u.fetchersLinux,
        outputFileName: "new-apps-linux.json",
        existingFileName: "apps-linux.json",
      }),
    );
    assert.equal(fs.existsSync(path.join(dir, "new-apps-linux.json")), false);
  });
}

test("a later asset page failing invalidates an already-discovered bundle", async (t) => {
  const dir = fixtureDir(t);
  const redis = redisAsset("8.10.3");
  const network = githubNetwork({
    releasePages: [[release(1)]],
    assetsByRelease: { 1: [redis] },
    override: (url) =>
      url === assetsApi("1") + "2"
        ? response({ message: "server error" }, { status: 500 })
        : null,
  });
  // Page 2 exists in the Link header chain, so the failure happens after
  // usable data was already parsed.
  const fetchWithSecondPage = async (url, init) => {
    if (url === assetsApi("1") + "1") {
      return response([redis], { next: assetsApi("1") + "2" });
    }
    return network.fetch(url, init);
  };
  const u = loadUpdater(fetchWithSecondPage, dir);

  await assert.rejects(() => u.fetchersLinux.redis(), /500/);
  await assert.rejects(() =>
    u.updatePlatformCatalog({
      platformName: "Linux",
      baseApps: u.baseLinuxApps,
      fetchers: u.fetchersLinux,
      outputFileName: "new-apps-linux.json",
      existingFileName: "apps-linux.json",
    }),
  );
  assert.equal(fs.existsSync(path.join(dir, "new-apps-linux.json")), false);
});

test("a successful empty scan does not resurrect a previously published Redis build", async (t) => {
  const dir = fixtureDir(t);
  const stale = redisAsset("8.10.3", { tag: "runtimes-2026-10-01" });
  fs.writeFileSync(
    path.join(dir, "apps-linux.json"),
    JSON.stringify({
      apps: [{ id: "redis", versions: { "8.10.3": stale.browser_download_url }, sha256: { "8.10.3": digest } }],
    }),
  );
  const network = githubNetwork({ releasePages: [[release(1)]], assetsByRelease: { 1: [] } });
  const u = loadUpdater(network.fetch, dir);

  await u.updatePlatformCatalog({
    platformName: "Linux",
    baseApps: u.baseLinuxApps,
    fetchers: u.fetchersLinux,
    outputFileName: "new-apps-linux.json",
    existingFileName: "apps-linux.json",
  });
  const catalog = JSON.parse(fs.readFileSync(path.join(dir, "new-apps-linux.json"), "utf8"));
  const redis = catalog.apps.find((app) => app.id === "redis");
  assert.deepEqual(plain(redis.versions), {});
  assert.equal(redis.sha256, undefined);
});

test("the GitHub token is sent only to the builder API, never to a foreign origin", async (t) => {
  const dir = fixtureDir(t);
  const redis = redisAsset("8.10.3");
  const seen = [];
  const network = githubNetwork({
    releasePages: [[release(1)], [release(2)]],
    assetsByRelease: { 1: [redis], 2: [] },
    override: (url, init) => {
      seen.push({ url, authorization: init?.headers?.Authorization });
      return null;
    },
  });
  const u = loadUpdater(network.fetch, dir, { env: { GITHUB_TOKEN: "secret-token" } });

  await u.fetchersLinux.redis();
  assert.ok(seen.length >= 3);
  for (const call of seen) {
    assert.ok(call.url.startsWith(apiOrigin + "/repos/" + repo + "/"), call.url);
    assert.equal(call.authorization, "Bearer secret-token");
  }
});

test("an off-origin release pagination link is rejected without being fetched", async (t) => {
  const dir = fixtureDir(t);
  const calls = [];
  const u = loadUpdater(async (url) => {
    calls.push(url);
    return response([], { next: "https://evil.example.com/repos/x/y/releases?page=2" });
  }, dir);

  await assert.rejects(() => u.fetchersLinux.redis(), /pagination link/i);
  assert.deepEqual(calls, [releasesApi + "1"]);
});

test("an off-origin asset pagination link is rejected without being fetched", async (t) => {
  const dir = fixtureDir(t);
  const calls = [];
  const u = loadUpdater(async (url) => {
    calls.push(url);
    if (url === releasesApi + "1") return response([release(1)]);
    if (url === assetsApi("1") + "1") {
      return response([], { next: "https://api.github.com/repos/other/repo/releases/1/assets?page=2" });
    }
    throw new Error(`Unexpected request: ${url}`);
  }, dir);

  await assert.rejects(() => u.fetchersLinux.redis(), /pagination link/i);
  assert.deepEqual(calls, [releasesApi + "1", assetsApi("1") + "1"]);
});

test("an asset pagination link to another release aborts without fetching or publishing", async (t) => {
  const dir = fixtureDir(t);
  const redis = redisAsset("8.10.3");
  const network = githubNetwork({
    releasePages: [[release(1)]],
    assetsByRelease: { 2: [redis] },
    override: (url) => url === assetsApi("1") + "1"
      ? response([], { next: assetsApi("2") + "1" })
      : null,
  });
  const u = loadUpdater(network.fetch, dir);

  await assert.rejects(() => u.updatePlatformCatalog({
    platformName: "Linux",
    baseApps: u.baseLinuxApps.filter((app) => app.id === "redis"),
    fetchers: u.fetchersLinux,
    outputFileName: "new-apps-linux.json",
    existingFileName: "apps-linux.json",
  }), /pagination link/i);
  assert.deepEqual(network.calls, [releasesApi + "1", assetsApi("1") + "1"]);
  assert.equal(fs.existsSync(path.join(dir, "new-apps-linux.json")), false);
});

test("a repeated asset pagination link is rejected", async (t) => {
  const dir = fixtureDir(t);
  const u = loadUpdater(async (url) => {
    if (url === releasesApi + "1") return response([release(1)]);
    if (url === assetsApi("1") + "1") return response([], { next: assetsApi("1") + "1" });
    throw new Error(`Unexpected request: ${url}`);
  }, dir);

  await assert.rejects(() => u.fetchersLinux.redis(), /Repeated/);
});

// --- Task 3: a successful unchanged run must still materialize its outputs ---

async function materialize(u, dir, platformName, outputFileName, existingFileName) {
  await u.updatePlatformCatalog({
    platformName,
    baseApps: platformName === "Linux" ? u.baseLinuxApps : u.baseWindowsApps,
    fetchers: platformName === "Linux" ? u.fetchersLinux : {},
    outputFileName,
    existingFileName,
  });
  return JSON.parse(fs.readFileSync(path.join(dir, outputFileName), "utf8"));
}

test("an unchanged run on a fresh checkout still writes both catalogs", async (t) => {
  const dir = fixtureDir(t);
  const php = phpAsset("8.4.27", { tag: "runtimes-2026-11-01" });
  const u = loadUpdater(githubNetwork({ releasePages: [[release(1)]], assetsByRelease: { 1: [php] } }).fetch, dir);

  const linux = await materialize(u, dir, "Linux", "new-apps-linux.json", "apps-linux.json");
  const windows = await materialize(u, dir, "Windows", "new-apps.json", "apps.json");
  assert.equal(linux.apps.find((app) => app.id === "php84").versions["8.4.27"], php.browser_download_url);
  assert.ok(windows.apps.length > 0);

  // Second run, same immutable input, and the generated files are removed so
  // only the committed templates remain, exactly like a fresh CI checkout.
  fs.writeFileSync(path.join(dir, "apps-linux.json"), JSON.stringify(linux));
  fs.writeFileSync(path.join(dir, "apps.json"), JSON.stringify(windows));
  fs.unlinkSync(path.join(dir, "new-apps-linux.json"));
  fs.unlinkSync(path.join(dir, "new-apps.json"));

  const linuxAgain = await materialize(u, dir, "Linux", "new-apps-linux.json", "apps-linux.json");
  const windowsAgain = await materialize(u, dir, "Windows", "new-apps.json", "apps.json");

  assert.deepEqual(linuxAgain.apps, linux.apps);
  assert.deepEqual(windowsAgain.apps, windows.apps);
  assert.equal(linuxAgain.lastUpdated, linux.lastUpdated);
  assert.equal(windowsAgain.lastUpdated, windows.lastUpdated);
});

test("a changed catalog gets a new timestamp", async (t) => {
  const dir = fixtureDir(t);
  const previousTimestamp = "2026-01-01T00:00:00.000Z";
  const php = phpAsset("8.4.27", { tag: "runtimes-2026-11-01" });
  fs.writeFileSync(
    path.join(dir, "apps-linux.json"),
    JSON.stringify({ version: "1.1.0", lastUpdated: previousTimestamp, apps: [] }),
  );
  const u = loadUpdater(githubNetwork({ releasePages: [[release(1)]], assetsByRelease: { 1: [php] } }).fetch, dir);

  const linux = await materialize(u, dir, "Linux", "new-apps-linux.json", "apps-linux.json");
  assert.notEqual(linux.lastUpdated, previousTimestamp);
  assert.equal(linux.apps.find((app) => app.id === "php84").versions["8.4.27"], php.browser_download_url);
});

test("an unchanged run keeps the previous timestamp even for a partial catalog", async (t) => {
  const dir = fixtureDir(t);
  const u = loadUpdater(githubNetwork({ releasePages: [[release(1)]], assetsByRelease: { 1: [] } }).fetch, dir);
  const previousTimestamp = "2026-02-02T00:00:00.000Z";

  const current = await materialize(u, dir, "Linux", "new-apps-linux.json", "apps-linux.json");
  fs.writeFileSync(
    path.join(dir, "apps-linux.json"),
    JSON.stringify({ ...current, lastUpdated: previousTimestamp }),
  );
  fs.unlinkSync(path.join(dir, "new-apps-linux.json"));

  const again = await materialize(u, dir, "Linux", "new-apps-linux.json", "apps-linux.json");
  assert.equal(again.lastUpdated, previousTimestamp);
  assert.deepEqual(again.apps, current.apps);
});

test("a stale checksum is never reattached to a different archive of the same version", async (t) => {
  const dir = fixtureDir(t);
  const previous = redisAsset("8.10.3", { tag: "runtimes-2026-10-01", build: "cccccccccccccccc" });
  const replacement = redisAsset("8.10.3", { tag: "runtimes-2026-11-06", build: "dddddddddddddddd", hash: "d".repeat(64) });
  const oldData = {
    apps: [
      {
        id: "redis",
        versions: { "8.10.3": previous.browser_download_url },
        sha256: { "8.10.3": digest },
      },
    ],
  };
  const u = loadUpdater(githubNetwork({}).fetch, dir);
  const app = u.baseLinuxApps.find((entry) => entry.id === "redis");
  // A rebuilt archive was published without a GitHub digest: the stored digest
  // belongs to the older archive and must not be attached to this URL.
  app.versions = { "8.10.3": replacement.browser_download_url };

  u.applyFallbackVersions(app, oldData, { versions: { "8.10.3": replacement.browser_download_url }, sha256: {} }, "Linux");

  assert.deepEqual(plain(app.versions), { "8.10.3": replacement.browser_download_url });
  assert.equal(app.sha256?.["8.10.3"], undefined);
});

test("Apache and PostgreSQL are discovered from musl-dynamic bundles", async (t) => {
  const apache = apacheAsset("2.4.70", { tag: "runtimes-2026-11-08" });
  const pg = postgresqlAsset("18.6", { tag: "runtimes-2026-11-08" });
  const network = githubNetwork({
    releasePages: [[release(1, { tag: "runtimes-2026-11-08" })]],
    assetsByRelease: { 1: [apache, pg] },
  });
  const u = loadUpdater(network.fetch, fixtureDir(t));

  const [a, p] = await Promise.all([u.fetchersLinux.apache(), u.fetchersLinux.postgresql()]);
  assert.deepEqual(plain(a.versions), { "2.4.70": apache.browser_download_url });
  assert.deepEqual(plain(p.versions), { "18.6": pg.browser_download_url });
  assert.deepEqual(plain(p.sha256), { "18.6": digest });
});

test("Apache and PostgreSQL ignore glibc, static-musl and aarch64 bundles", async (t) => {
  const network = githubNetwork({
    releasePages: [[release(1, { tag: "runtimes-2026-11-08" })]],
    assetsByRelease: { 1: [
      apacheAsset("2.4.70", { target: "glibc-x86_64" }),
      apacheAsset("2.4.71", { target: "musl-x86_64" }),
      postgresqlAsset("18.6", { target: "musl-dynamic-aarch64" }),
      { name: "postgresql-18.6.tar.gz", browser_download_url: "https://example.com/pg.tar.gz" },
    ] },
  });
  const u = loadUpdater(network.fetch, fixtureDir(t));
  assert.deepEqual(plain((await u.fetchersLinux.apache()).versions), {});
  assert.deepEqual(plain((await u.fetchersLinux.postgresql()).versions), {});
});

test("Apache and PostgreSQL fall back only to builder bundles that still match", async (t) => {
  const u = loadUpdater(async () => { throw Error("Unexpected network request"); }, fixtureDir(t));
  const cases = [
    { id: "apache", version: "2.4.70", asset: apacheAsset("2.4.70") },
    { id: "postgresql", version: "18.6", asset: postgresqlAsset("18.6") },
  ];
  for (const { id, version, asset } of cases) {
    const app = u.baseLinuxApps.find((a) => a.id === id);
    const old = { apps: [{ id, versions: {
      [version]: asset.browser_download_url,
      "9.9.9": `https://github.com/ngotuananh101/devstack-app-builder/releases/download/x/${id}-9.9.9-glibc-x86_64-abcdef0123456789.tar.gz`,
      latest: "https://example.com/source.tar.gz",
    } }] };
    u.applyFallbackVersions(app, old, null, "Linux");
    assert.deepEqual(Object.keys(app.versions), [version]);
    assert.equal(app.versions[version], asset.browser_download_url);
  }
});

