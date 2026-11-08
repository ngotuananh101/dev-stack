"use strict";

// Shared fixtures for the offline updater suites. Everything here builds
// in-memory GitHub responses; no test touches the network or the live catalogs.

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const vm = require("node:vm");

const repo = "ngotuananh101/devstack-app-builder";
const apiOrigin = "https://api.github.com";
const releasesApi = `${apiOrigin}/repos/${repo}/releases?per_page=100&page=`;
const assetsApi = (id) =>
  `${apiOrigin}/repos/${repo}/releases/${id}/assets?per_page=100&page=`;
const digest = "a".repeat(64);

const sourcePath = path.resolve("assets/data/update.js");

function response(data, { status = 200, next, link = null } = {}) {
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: {
      get(name) {
        if (name.toLowerCase() !== "link") return null;
        if (link) return link;
        return next ? `<${next}>; rel="next"` : null;
      },
    },
    json: async () => data,
  };
}

function fixtureDir(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "updater-fixture-"));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  return dir;
}

function loadUpdater(fetch, dataDir, { env = {} } = {}) {
  const context = vm.createContext({
    require,
    module: { exports: {} },
    process: { env },
    __dirname: dataDir,
    structuredClone,
    fetch,
    console: { log() {}, error() {}, warn() {} },
    URL,
  });
  // The guarded CLI entrypoint does not run when loaded for offline tests.
  vm.runInContext(fs.readFileSync(sourcePath, "utf8"), context);
  return vm.runInContext(
    "({ fetchersLinux, fetchersWindows, fetchMariadbReleases, createLinuxPhpApps, applyFetchedVersions, applyFallbackVersions, baseLinuxApps, baseWindowsApps, updatePlatformCatalog })",
    context,
  );
}

function bundleUrl(tag, name) {
  return `https://github.com/${repo}/releases/download/${tag}/${name}`;
}

const BUILDER_TARGETS = { php: "musl-dynamic", apache: "musl-dynamic", postgresql: "musl-dynamic", redis: "musl" };

function bundleAsset(runtime, version, options = {}) {
  const { tag = "runtimes-2026-11-06", build = "abcdef0123456789", hash = digest, name, url } = options;
  const target = options.target ?? `${BUILDER_TARGETS[runtime]}-x86_64`;
  const assetName = name ?? `${runtime}-${version}-${target}-${build}.tar.gz`;
  return {
    name: assetName,
    browser_download_url: url ?? bundleUrl(tag, assetName),
    ...(hash ? { digest: `sha256:${hash}` } : {}),
  };
}

const phpAsset = (version, options) => bundleAsset("php", version, options);
const redisAsset = (version, options) => bundleAsset("redis", version, options);
const apacheAsset = (version, options) => bundleAsset("apache", version, options);
const postgresqlAsset = (version, options) => bundleAsset("postgresql", version, options);

// Releases carry no embedded assets: the updater must read the per-release
// assets endpoint, exactly as a real, complete scan does.
function release(id, options = {}) {
  const { tag = `runtimes-2026-11-${id}`, draft = false, prerelease = false, assets = [] } =
    options;
  return { id, tag_name: tag, draft, prerelease, assets };
}

function assetPages(spec) {
  if (!Array.isArray(spec) || spec.length === 0) return [[]];
  return Array.isArray(spec[0]) ? spec : [spec];
}

/**
 * Mock of the builder API. `releasePages` is the paginated release list;
 * `assetsByRelease` maps a release id to one page of assets or a list of pages.
 * `override(url)` may return a response to short-circuit a request.
 */
function githubNetwork({ releasePages = [], assetsByRelease = {}, override } = {}) {
  const calls = [];
  const answered = [];
  const fetch = async (url, init) => {
    calls.push(url);
    const overridden = override?.(url, init);
    if (overridden) return overridden;

    const releasePage = new RegExp(
      `^${releasesApi.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}(\\d+)$`,
    ).exec(url);
    if (releasePage) {
      const index = Number(releasePage[1]) - 1;
      const page = releasePages[index];
      if (!page) throw new Error(`No fixture for release page ${releasePage[1]}`);
      answered.push(url);
      return response(page, {
        next: releasePages[index + 1] ? releasesApi + (index + 2) : null,
      });
    }

    const assetPage = new RegExp(
      `^${apiOrigin}/repos/${repo}/releases/(\\d+)/assets\\?per_page=100&page=(\\d+)$`,
    ).exec(url);
    if (assetPage) {
      const pages = assetPages(assetsByRelease[assetPage[1]] ?? []);
      const page = pages[Number(assetPage[2]) - 1];
      if (!page) throw new Error(`No fixture for assets page ${url}`);
      answered.push(url);
      return response(page, {
        next: pages[Number(assetPage[2])] ? assetsApi(assetPage[1]) + (Number(assetPage[2]) + 1) : null,
      });
    }

    throw new Error(`Unexpected network request: ${url}`);
  };
  return { fetch, calls, answered };
}

const plain = (value) => JSON.parse(JSON.stringify(value));

module.exports = {
  apacheAsset,
  apiOrigin,
  assetsApi,
  assetPages,
  bundleAsset,
  bundleUrl,
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
};
