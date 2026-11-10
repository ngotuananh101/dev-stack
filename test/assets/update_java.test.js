"use strict";

// The JDK is published by Eclipse Adoptium rather than under one release
// index, so the updater asks Adoptium which feature versions still exist and
// then reads the newest build of each. These tests pin down what the catalog
// gets: one entry per feature version, the publisher's checksum, and the
// version key spelled the way `java -version` and every build tool expect.

const test = require("node:test");
const assert = require("node:assert/strict");
const { fixtureDir, loadUpdater, plain, response } = require("./updater_test_helpers.cjs");

const RELEASES_INDEX = "https://api.adoptium.net/v3/info/available_releases";
const latestUrl = (feature, os) =>
  `https://api.adoptium.net/v3/assets/latest/${feature}/hotspot?architecture=x64&image_type=jdk&os=${os}&vendor=eclipse`;

const SHA_JAVA = "d".repeat(64);

const INDEX = {
  available_lts_releases: [8, 11, 17, 21, 25],
  available_releases: [8, 11, 16, 17, 20, 21, 25, 26, 27],
  most_recent_feature_release: 27,
  most_recent_feature_version: 28,
  most_recent_lts: 25,
  tip_version: 28,
};

function latest(feature, os, { releaseName, version, checksum = SHA_JAVA, arch = "x64", imageType = "jdk" } = {}) {
  const ext = os === "windows" ? "zip" : "tar.gz";
  const name = `OpenJDK${feature}U-jdk_${arch}_${os}_hotspot_${version}.${ext}`;
  // Adoptium spells the build separator as `+` in `release_name` but as `%2B`
  // in the download path; the fixture mirrors both so a URL claim stays honest.
  const tag = releaseName.replace(/\+/g, "%2B");
  return [
    {
      binary: {
        architecture: arch,
        os,
        image_type: imageType,
        heap_size: "normal",
        jvm_impl: "hotspot",
        package: {
          name,
          link: `https://github.com/adoptium/temurin${feature}-binaries/releases/download/${tag}/${name}`,
          checksum,
          size: 1024,
          package_type: "archive",
        },
      },
      release_name: releaseName,
    },
  ];
}

function network(routes) {
  const calls = [];
  const fetch = async (url) => {
    calls.push(url);
    if (!(url in routes)) throw new Error(`Unexpected network request: ${url}`);
    return response(routes[url]);
  };
  return { fetch, calls };
}

/** Every feature version the updater is expected to ask Adoptium about. */
function askFor(routes, features, os) {
  for (const feature of features) routes[latestUrl(feature, os)] = [];
  return routes;
}

test("Java exposes one build per supported feature version", async (t) => {
  const routes = { [RELEASES_INDEX]: INDEX };
  askFor(routes, [8, 11, 17, 21, 25, 26, 27], "linux");
  routes[latestUrl(8, "linux")] = latest(8, "linux", {
    releaseName: "jdk8u512-b09",
    version: "8u512b09",
  });
  routes[latestUrl(11, "linux")] = latest(11, "linux", {
    releaseName: "jdk-11.0.33+10",
    version: "11.0.33_10",
  });
  routes[latestUrl(17, "linux")] = latest(17, "linux", {
    releaseName: "jdk-17.0.21+9",
    version: "17.0.21_9",
  });
  routes[latestUrl(21, "linux")] = latest(21, "linux", {
    releaseName: "jdk-21.0.13+9",
    version: "21.0.13_9",
  });
  routes[latestUrl(25, "linux")] = latest(25, "linux", {
    releaseName: "jdk-25.0.5+8",
    version: "25.0.5_8",
  });
  routes[latestUrl(26, "linux")] = latest(26, "linux", {
    releaseName: "jdk-26.0.2.1+1",
    version: "26.0.2.1_1",
  });
  routes[latestUrl(27, "linux")] = latest(27, "linux", {
    releaseName: "jdk-27.0.1.0.2+1",
    version: "27.0.1.0.2_1",
  });

  const u = loadUpdater(network(routes).fetch, fixtureDir(t));
  const result = plain(await u.fetchersLinux.java());

  assert.deepEqual(Object.keys(result.versions), [
    "27.0.1.0.2",
    "26.0.2.1",
    "25.0.5",
    "21.0.13",
    "17.0.21",
    "11.0.33",
    "8.0.512",
  ]);
  assert.equal(
    result.versions["8.0.512"],
    "https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u512-b09/OpenJDK8U-jdk_x64_linux_hotspot_8u512b09.tar.gz",
    "a JDK 8 release name has no dotted version; it must still key on 8.0.512",
  );
  assert.equal(
    result.versions["27.0.1.0.2"],
    "https://github.com/adoptium/temurin27-binaries/releases/download/jdk-27.0.1.0.2%2B1/OpenJDK27U-jdk_x64_linux_hotspot_27.0.1.0.2_1.tar.gz",
    "the update metadata understates this build; the package name is authoritative",
  );
  assert.deepEqual(result.sha256, {
    "27.0.1.0.2": SHA_JAVA,
    "26.0.2.1": SHA_JAVA,
    "25.0.5": SHA_JAVA,
    "21.0.13": SHA_JAVA,
    "17.0.21": SHA_JAVA,
    "11.0.33": SHA_JAVA,
    "8.0.512": SHA_JAVA,
  });
});

test("Java skips only the feature versions Adoptium has no build for", async (t) => {
  const routes = { [RELEASES_INDEX]: INDEX };
  askFor(routes, [8, 11, 17, 21, 25, 26, 27], "linux");
  routes[latestUrl(21, "linux")] = latest(21, "linux", {
    releaseName: "jdk-21.0.13+9",
    version: "21.0.13_9",
  });
  routes[latestUrl(25, "linux")] = [];
  routes[latestUrl(26, "linux")] = latest(26, "linux", {
    releaseName: "jdk-26.0.2.1+1",
    version: "26.0.2.1_1",
  });

  const u = loadUpdater(network(routes).fetch, fixtureDir(t));
  const result = plain(await u.fetchersLinux.java());

  assert.deepEqual(Object.keys(result.versions), ["26.0.2.1", "21.0.13"]);
});

test("Java ignores binaries that are not the x64 JDK archive", async (t) => {
  const routes = { [RELEASES_INDEX]: INDEX };
  askFor(routes, [8, 11, 17, 21, 25, 26, 27], "linux");
  routes[latestUrl(21, "linux")] = [
    ...latest(21, "linux", {
      releaseName: "jdk-21.0.13+9",
      version: "21.0.13_9",
      arch: "aarch64",
    }),
    ...latest(21, "linux", {
      releaseName: "jdk-21.0.13+9",
      version: "21.0.13_9",
      imageType: "jre",
    }),
    ...latest(21, "linux", {
      releaseName: "jdk-21.0.13+9",
      version: "21.0.13_9",
    }),
  ];

  const u = loadUpdater(network(routes).fetch, fixtureDir(t));
  const result = plain(await u.fetchersLinux.java());

  assert.deepEqual(Object.keys(result.versions), ["21.0.13"]);
  assert.match(result.versions["21.0.13"], /OpenJDK21U-jdk_x64_linux_hotspot_21\.0\.13_9\.tar\.gz$/);
});

test("Java on Windows asks Adoptium for Windows builds", async (t) => {
  const routes = { [RELEASES_INDEX]: INDEX };
  askFor(routes, [8, 11, 17, 21, 25, 26, 27], "windows");
  routes[latestUrl(21, "windows")] = latest(21, "windows", {
    releaseName: "jdk-21.0.13+9",
    version: "21.0.13_9",
  });

  const { fetch, calls } = network(routes);
  const u = loadUpdater(fetch, fixtureDir(t));
  const result = plain(await u.fetchersWindows.java());

  assert.deepEqual(Object.keys(result.versions), ["21.0.13"]);
  assert.ok(
    calls.every((url) => !url.includes("os=linux")),
    "the Windows catalog must not advertise Linux archives",
  );
  assert.match(result.versions["21.0.13"], /windows.*\.zip$/);
});

test("Java reports the failure instead of an empty catalog when Adoptium is unreachable", async (t) => {
  const u = loadUpdater(async () => {
    throw new Error("offline");
  }, fixtureDir(t));

  await assert.rejects(() => u.fetchersLinux.java());
});

test("both catalogs ship Java as one multi-version runtime", async (t) => {
  const u = loadUpdater(async () => response({}), fixtureDir(t));

  for (const apps of [u.baseWindowsApps, u.baseLinuxApps]) {
    const matches = apps.filter((app) => app.id === "java");
    assert.equal(matches.length, 1, "Java is one app with versions, not one app per JDK");
    const java = matches[0];
    assert.equal(java.category, "runtime");
    assert.equal(java.group_name, "java");
  }

  const windows = u.baseWindowsApps.find((app) => app.id === "java");
  const linux = u.baseLinuxApps.find((app) => app.id === "java");
  assert.equal(windows.exec_file, "java.exe");
  assert.equal(windows.cli_file, "javac.exe");
  assert.equal(linux.exec_file, "java");
  assert.equal(linux.cli_file, "javac");
});
