"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  fixtureDir,
  loadUpdater,
  plain,
  response,
} = require("./updater_test_helpers.cjs");

const API = "https://api.github.com/repos/mongodb-js/compass/releases";
const SHA = "a".repeat(64);
const url = (version, name = `mongodb-compass-${version}-linux-x64.tar.gz`) =>
  `https://github.com/mongodb-js/compass/releases/download/v${version}/${name}`;
const releaseId = (version) => Number(version.replaceAll(".", ""));
const asset = (version, overrides = {}) => ({
  name: `mongodb-compass-${version}-linux-x64.tar.gz`,
  browser_download_url: url(version),
  digest: `sha256:${SHA}`,
  ...overrides,
});
const release = (version, overrides = {}) => ({
  id: releaseId(version),
  tag_name: `v${version}`,
  draft: false,
  prerelease: false,
  assets: [asset(version)],
  ...overrides,
});
const linuxApp = () => ({ id: "mongodb-compass", exec_file: "MongoDB Compass" });

function compassFetch(releasePages, assetPages = {}) {
  return async (request) => {
    if (Object.hasOwn(releasePages, request)) return releasePages[request];
    const match = new RegExp(
      `^${API}/(\\d+)/assets\\?per_page=100&page=(\\d+)$`,
    ).exec(request);
    if (!match) throw new Error(`Unexpected request ${request}`);
    const page = assetPages[Number(match[1])]?.[Number(match[2])];
    if (!page) throw new Error(`Unexpected release asset request ${request}`);
    return page;
  };
}

function releaseAssetPages(releases, getAssets = (entry) => entry.assets) {
  return Object.fromEntries(
    releases.map((entry) => [
      releaseId(entry.tag_name.slice(1)),
      { 1: response(getAssets(entry)) },
    ]),
  );
}

test("Compass uses the CI token only on fixed API requests and rejects redirects", async (t) => {
  const entry = release("1.53.2");
  const releasePage = `${API}?per_page=100&page=1`;
  const assetPage = `${API}/${entry.id}/assets?per_page=100&page=1`;
  const calls = [];
  const updater = loadUpdater(async (request, init) => {
    calls.push([request, init.headers.Authorization, init.redirect]);
    if (request === releasePage) return response([entry]);
    if (request === assetPage) return response(entry.assets);
    throw new Error(`Unexpected request ${request}`);
  }, fixtureDir(t), { env: { GITHUB_TOKEN: "fixture-token" } });

  assert.equal((await updater.fetchersLinux["mongodb-compass"]()).versions["1.53.2"], url("1.53.2"));
  assert.deepEqual(calls, [
    [releasePage, "Bearer fixture-token", "error"],
    [assetPage, "Bearer fixture-token", "error"],
  ]);
});

test("Compass works without a token and never follows supplied pagination origins", async (t) => {
  const entry = release("1.53.2");
  const calls = [];
  const updater = loadUpdater(async (request, init) => {
    calls.push(request);
    assert.equal(Object.hasOwn(init.headers, "Authorization"), false);
    if (request === `${API}?per_page=100&page=1`) {
      return response([entry], { next: "https://foreign.test/releases?page=2" });
    }
    if (request === `${API}?per_page=100&page=2`) return response([]);
    if (request === `${API}/${entry.id}/assets?per_page=100&page=1`) {
      return response(entry.assets, { next: "https://foreign.test/assets?page=2" });
    }
    if (request === `${API}/${entry.id}/assets?per_page=100&page=2`) return response([]);
    throw new Error(`Unexpected request ${request}`);
  }, fixtureDir(t));

  assert.equal((await updater.fetchersLinux["mongodb-compass"]()).versions["1.53.2"], url("1.53.2"));
  assert.equal(calls.length, 4);
  assert.ok(calls.every((request) => request.startsWith(`${API}?`) || request.startsWith(`${API}/`)));
});

test("Linux chooses only the standard linux-x64 tarball and its SHA256", async (t) => {
  const version = "1.53.2";
  const alternatives = [
    "rhel-x64.tar.gz",
    "linux-arm64.tar.gz",
    "linux-x64.tar.gz.sig",
    "win32-x64.zip",
  ].map((suffix) =>
    asset(version, {
      name: `mongodb-compass-${version}-${suffix}`,
      browser_download_url: url(version, `mongodb-compass-${version}-${suffix}`),
    }),
  );
  alternatives.push(
    asset(version, { name: `mongodb-compass-readonly-${version}-linux-x64.tar.gz` }),
    asset(version, { name: `mongodb-compass-isolated-${version}-linux-x64.tar.gz` }),
    asset(version),
  );
  const releases = [
    release(version),
    release("1.53.1"),
    release("1.52.0"),
  ];
  const assets = releaseAssetPages(releases, (entry) =>
    entry.tag_name === `v${version}` ? alternatives : entry.assets,
  );
  const updater = loadUpdater(
    compassFetch({ [`${API}?per_page=100&page=1`]: response(releases) }, assets),
    fixtureDir(t),
  );

  const result = await updater.fetchersLinux["mongodb-compass"]();
  const app = linuxApp();
  updater.applyFetchedVersions(app, result);

  assert.deepEqual(plain(app.versions), {
    "1.53.2": url("1.53.2"),
    "1.52.0": url("1.52.0"),
  });
  assert.deepEqual(plain(app.sha256), { "1.53.2": SHA, "1.52.0": SHA });
});

test("Linux skips drafts, prereleases, and assets with invalid URL or digest", async (t) => {
  const releases = [
    release("1.53.2", { draft: true }),
    release("1.54.0", { prerelease: true }),
    release("1.52.0", { assets: [] }),
    release("1.51.0"),
    release("1.50.0"),
    release("1.49.0"),
    release("1.48.0"),
  ];
  const assets = releaseAssetPages(releases, (entry) => {
    switch (entry.tag_name) {
      case "v1.51.0":
        return [asset("1.51.0", { digest: null })];
      case "v1.50.0":
        return [asset("1.50.0", { digest: "sha256:bad" })];
      case "v1.49.0":
        return [asset("1.49.0", { browser_download_url: "https://evil.test/archive.tar.gz" })];
      case "v1.48.0":
        return [asset("1.48.0", { browser_download_url: url("1.47.0") })];
      default:
        return entry.assets;
    }
  });
  const updater = loadUpdater(
    compassFetch({ [`${API}?per_page=100&page=1`]: response(releases) }, assets),
    fixtureDir(t),
  );

  assert.deepEqual(plain(await updater.fetchersLinux["mongodb-compass"]()), {
    versions: {},
    sha256: {},
  });
});

test("Linux reads later release pages and fails an incomplete release scan", async (t) => {
  const first = [release("1.53.2")];
  const second = [release("1.52.0")];
  const assets = releaseAssetPages([...first, ...second]);
  const updater = loadUpdater(
    compassFetch(
      {
        [`${API}?per_page=100&page=1`]: response(first, {
          next: `${API}?per_page=100&page=2`,
        }),
        [`${API}?per_page=100&page=2`]: response(second),
      },
      assets,
    ),
    fixtureDir(t),
  );
  const result = await updater.fetchersLinux["mongodb-compass"]();
  assert.equal(result.versions["1.52.0"], url("1.52.0"));

  const broken = loadUpdater(
    async () => response({}, { status: 503 }),
    fixtureDir(t),
  );
  await assert.rejects(() => broken.fetchersLinux["mongodb-compass"]());
});

test("Linux reads and paginates each release's complete asset list", async (t) => {
  const version = "1.53.2";
  const entry = release(version, { assets: [] });
  const id = releaseId(version);
  const wrongPage = asset(version, {
    name: `mongodb-compass-${version}-rhel-x64.tar.gz`,
    browser_download_url: url(version, `mongodb-compass-${version}-rhel-x64.tar.gz`),
  });
  const expectedUrl = `${API}/${id}/assets?per_page=100&page=2`;
  const updater = loadUpdater(
    compassFetch(
      { [`${API}?per_page=100&page=1`]: response([entry]) },
      {
        [id]: {
          1: response([wrongPage], { next: expectedUrl }),
          2: response([asset(version)]),
        },
      },
    ),
    fixtureDir(t),
  );

  assert.deepEqual(
    plain(await updater.fetchersLinux["mongodb-compass"]()),
    { versions: { [version]: url(version) }, sha256: { [version]: SHA } },
  );
});

test("Linux fails when any page of a release asset list cannot be read", async (t) => {
  const version = "1.53.2";
  const id = releaseId(version);
  const next = `${API}/${id}/assets?per_page=100&page=2`;
  const updater = loadUpdater(
    compassFetch(
      { [`${API}?per_page=100&page=1`]: response([release(version, { assets: [] })]) },
      {
        [id]: {
          1: response([asset(version)], { next }),
          2: response([], { status: 503 }),
        },
      },
    ),
    fixtureDir(t),
  );

  await assert.rejects(() => updater.fetchersLinux["mongodb-compass"]());
});

test("fallback restores only matching official URL and SHA256 pairs on Linux", (t) => {
  const updater = loadUpdater(async () => response([]), fixtureDir(t));
  const app = linuxApp();
  updater.applyFallbackVersions(app, {
    apps: [
      {
        ...linuxApp(),
        versions: {
          "1.53.2": url("1.53.2"),
          "1.52.0": url("1.52.0", "mongodb-compass-1.52.0-rhel-x64.tar.gz"),
          "1.51.0": url("1.51.0"),
          "1.50.0": "https://evil.test/compass.tar.gz",
        },
        sha256: {
          "1.53.2": SHA,
          "1.52.0": SHA,
          "1.51.0": "bad",
          "1.50.0": SHA,
        },
      },
    ],
  });
  assert.deepEqual(plain(app.versions), { "1.53.2": url("1.53.2") });
  assert.deepEqual(plain(app.sha256), { "1.53.2": SHA });
});

test("Windows Compass continues to select the portable ZIP", async (t) => {
  const version = "1.53.2";
  const name = `mongodb-compass-${version}-win32-x64.zip`;
  const updater = loadUpdater(
    async () =>
      response([
        release(version, {
          assets: [asset(version), { name, browser_download_url: url(version, name) }],
        }),
      ]),
    fixtureDir(t),
  );
  assert.deepEqual(
    plain(await updater.fetchersWindows.github("mongodb-js/compass")),
    { [version]: url(version, name) },
  );
});
