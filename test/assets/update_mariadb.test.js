"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { fixtureDir, loadUpdater, plain, response } = require("./updater_test_helpers.cjs");

test("MariaDB fetcher rewrites http download URLs to https and preserves existing https URLs", async (t) => {
  const rootApi = "https://downloads.mariadb.org/rest-api/mariadb/";
  const majorApi = "https://downloads.mariadb.org/rest-api/mariadb/11.4";

  const rootPayload = {
    major_releases: [
      { release_id: "11.4", release_status: "Active" },
      { release_id: "11.5", release_status: "Preview" },
    ],
  };

  const httpUrl = "http://mirror.mariadb.org/11.4.5/mariadb-11.4.5-linux-systemd-x86_64.tar.gz";
  const expectedHttpsUrl = "https://mirror.mariadb.org/11.4.5/mariadb-11.4.5-linux-systemd-x86_64.tar.gz";
  const alreadyHttpsUrl = "https://downloads.mariadb.org/f/mariadb-11.4.4/mariadb-11.4.4-linux-systemd-x86_64.tar.gz";

  const majorPayload = {
    releases: {
      "11.4.5": {
        files: [
          {
            file_name: "mariadb-11.4.5-linux-systemd-x86_64.tar.gz",
            file_download_url: httpUrl,
          },
        ],
      },
      "11.4.4": {
        files: [
          {
            file_name: "mariadb-11.4.4-linux-systemd-x86_64.tar.gz",
            file_download_url: alreadyHttpsUrl,
          },
        ],
      },
    },
  };

  const fakeFetch = async (url) => {
    if (url === rootApi) return response(rootPayload);
    if (url === majorApi) return response(majorPayload);
    throw new Error(`Unexpected request: ${url}`);
  };

  const u = loadUpdater(fakeFetch, fixtureDir(t));

  // 1. Direct call to fetchMariadbReleases
  const versionsDirect = await u.fetchMariadbReleases((f) =>
    f.file_name?.endsWith("-linux-systemd-x86_64.tar.gz"),
  );

  // Assert an http:// MariaDB file_download_url becomes https://
  assert.equal(versionsDirect["11.4.5"], expectedHttpsUrl);
  // Assert an already-https:// URL is left byte-identical
  assert.strictEqual(versionsDirect["11.4.4"], alreadyHttpsUrl);

  // 2. Integration call via fetchersLinux.mariadb()
  const versionsLinux = await u.fetchersLinux.mariadb();
  assert.deepEqual(plain(versionsLinux), {
    "11.4.5": expectedHttpsUrl,
    "11.4.4": alreadyHttpsUrl,
  });
});
