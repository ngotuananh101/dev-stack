"use strict";

// Go and Flutter publish their own release indexes rather than GitHub
// releases. These tests pin down what the updater reads from them: stable
// builds only, the newest patch of each minor, real download URLs, and the
// checksums the installer verifies before unpacking a multi-gigabyte payload.

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  fixtureDir,
  loadUpdater,
  plain,
  response,
} = require("./updater_test_helpers.cjs");

const GO_INDEX = "https://go.dev/dl/?mode=json&include=all";
const FLUTTER_LINUX_INDEX =
  "https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json";
const FLUTTER_WINDOWS_INDEX =
  "https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json";
const SHA_GO = "b".repeat(64);
const SHA_FLUTTER = "c".repeat(64);

function goFile(version, os, ext) {
  return {
    filename: `go${version}.${os}-amd64.${ext}`,
    os,
    arch: "amd64",
    version: `go${version}`,
    sha256: SHA_GO,
    size: 1,
    kind: "archive",
  };
}

function goRelease(version, { stable = true } = {}) {
  return {
    version: `go${version}`,
    stable,
    files: [
      goFile(version, "linux", "tar.gz"),
      goFile(version, "windows", "zip"),
      // Non-amd64 and non-archive entries must never become a download.
      { ...goFile(version, "linux", "tar.gz"), arch: "arm64" },
      {
        ...goFile(version, "linux", "tar.gz"),
        kind: "source",
        filename: `go${version}.src.tar.gz`,
      },
    ],
  };
}

function flutterRelease(version, os, { channel = "stable" } = {}) {
  return {
    hash: "h".repeat(40),
    channel,
    version,
    dart_sdk_version: "3.13.7",
    release_date: "2026-10-29T19:22:44.517205Z",
    archive:
      os === "linux"
        ? `stable/linux/flutter_linux_${version}-stable.tar.xz`
        : `stable/windows/flutter_windows_${version}-stable.zip`,
    sha256: SHA_FLUTTER,
  };
}

function flutterIndex(releases) {
  return {
    base_url: "https://storage.googleapis.com/flutter_infra_release/releases",
    current_release: { stable: "h".repeat(40) },
    releases,
  };
}

function network(routes) {
  return async (url) => {
    if (!(url in routes)) throw new Error(`Unexpected network request: ${url}`);
    return response(routes[url]);
  };
}

test("Go exposes the newest patch of every minor with amd64 archives only", async (t) => {
  const u = loadUpdater(
    network({
      [GO_INDEX]: [
        goRelease("1.27.3"),
        goRelease("1.27.2"),
        goRelease("1.26.10"),
        goRelease("1.28.0", { stable: false }),
      ],
    }),
    fixtureDir(t),
  );

  const windows = plain(await u.fetchersWindows.go());
  const linux = plain(await u.fetchersLinux.go());

  assert.deepEqual(Object.keys(windows.versions), ["1.27.3", "1.26.10"]);
  assert.equal(
    windows.versions["1.27.3"],
    "https://go.dev/dl/go1.27.3.windows-amd64.zip",
  );
  assert.deepEqual(Object.keys(linux.versions), ["1.27.3", "1.26.10"]);
  assert.equal(
    linux.versions["1.27.3"],
    "https://go.dev/dl/go1.27.3.linux-amd64.tar.gz",
  );
  assert.deepEqual(windows.sha256, {
    "1.27.3": SHA_GO,
    "1.26.10": SHA_GO,
  });
  assert.equal(
    linux.sha256["1.27.3"],
    SHA_GO,
    "the checksum published by go.dev must reach the installer",
  );
});

test("Go reports the failure instead of an empty catalog when offline", async (t) => {
  const u = loadUpdater(async () => {
    throw new Error("offline");
  }, fixtureDir(t));

  await assert.rejects(() => u.fetchersLinux.go());
});

test("Flutter keeps stable builds only and resolves archives against base_url", async (t) => {
  const u = loadUpdater(
    network({
      [FLUTTER_LINUX_INDEX]: flutterIndex([
        flutterRelease("3.47.9", "linux"),
        flutterRelease("3.47.8", "linux"),
        flutterRelease("3.47.6", "linux"),
        flutterRelease("3.44.1", "linux"),
        flutterRelease("3.48.0", "linux", { channel: "beta" }),
        flutterRelease("v1.2.1", "linux"),
      ]),
    }),
    fixtureDir(t),
  );

  const result = plain(await u.fetchersLinux.flutter());

  assert.deepEqual(Object.keys(result.versions), ["3.47.9", "3.44.1"]);
  assert.equal(
    result.versions["3.47.9"],
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.9-stable.tar.xz",
  );
  assert.deepEqual(result.sha256, {
    "3.47.9": SHA_FLUTTER,
    "3.44.1": SHA_FLUTTER,
  });
});

test("Flutter on Windows asks for the Windows index", async (t) => {
  const requests = [];
  const u = loadUpdater(async (url) => {
    requests.push(url);
    return response(flutterIndex([flutterRelease("3.47.9", "windows")]));
  }, fixtureDir(t));

  const result = plain(await u.fetchersWindows.flutter());

  assert.deepEqual(requests, [FLUTTER_WINDOWS_INDEX]);
  assert.equal(
    result.versions["3.47.9"],
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.47.9-stable.zip",
  );
});

test("catalog application keeps the checksums Go and Flutter reported", async (t) => {
  const u = loadUpdater(async () => response({}), fixtureDir(t));
  const app = { id: "go", versions: {} };
  u.applyFetchedVersions(app, {
    versions: { "1.27.3": "https://go.dev/dl/go1.27.3.linux-amd64.tar.gz" },
    sha256: { "1.27.3": SHA_GO },
  });

  assert.deepEqual(plain(app.versions), {
    "1.27.3": "https://go.dev/dl/go1.27.3.linux-amd64.tar.gz",
  });
  assert.deepEqual(plain(app.sha256), { "1.27.3": SHA_GO });
});

test("a failed Go fetch keeps the last published URLs and checksums", async (t) => {
  const u = loadUpdater(async () => response({}), fixtureDir(t));
  const app = { id: "go", versions: {} };
  const url = "https://go.dev/dl/go1.27.3.linux-amd64.tar.gz";
  u.applyFallbackVersions(
    app,
    {
      apps: [
        {
          id: "go",
          versions: { "1.27.3": url },
          sha256: { "1.27.3": SHA_GO },
        },
      ],
    },
    null,
  );

  assert.deepEqual(plain(app.versions), { "1.27.3": url });
  assert.deepEqual(plain(app.sha256), { "1.27.3": SHA_GO });
});

test("both catalogs ship Go and Flutter as installable runtimes", async (t) => {
  const u = loadUpdater(async () => response({}), fixtureDir(t));

  for (const apps of [u.baseWindowsApps, u.baseLinuxApps]) {
    const go = apps.find((app) => app.id === "go");
    const flutter = apps.find((app) => app.id === "flutter");
    assert.ok(go, "Go must be in the catalog");
    assert.ok(flutter, "Flutter must be in the catalog");
    assert.equal(go.category, "runtime");
    assert.equal(flutter.category, "runtime");
    assert.equal(go.group_name, "go");
    assert.equal(flutter.group_name, "flutter");
  }

  const windowsGo = u.baseWindowsApps.find((app) => app.id === "go");
  const linuxGo = u.baseLinuxApps.find((app) => app.id === "go");
  assert.equal(windowsGo.exec_file, "go.exe");
  assert.equal(windowsGo.cli_file, "go.exe");
  assert.equal(linuxGo.exec_file, "go");
  assert.equal(linuxGo.cli_file, "go");

  const windowsFlutter = u.baseWindowsApps.find((app) => app.id === "flutter");
  const linuxFlutter = u.baseLinuxApps.find((app) => app.id === "flutter");
  assert.equal(windowsFlutter.exec_file, "flutter.bat");
  assert.equal(windowsFlutter.cli_file, "dart.bat");
  assert.equal(linuxFlutter.exec_file, "flutter");
  assert.equal(linuxFlutter.cli_file, "dart");
});
