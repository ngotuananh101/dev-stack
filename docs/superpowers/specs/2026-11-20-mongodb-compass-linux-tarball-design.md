# MongoDB Compass Linux Tarball Integration Design

**Status:** Implementation in progress; cross-distribution launch validation is pending.

**Date:** 2026-11-20

## Scope

Add MongoDB Compass as a managed Linux x64 GUI tool. Users can select a version, install it under DevStack's managed app directory, open it from Apps or Databases, and uninstall it without affecting MongoDB Server. Preserve the existing Windows catalog and launch behavior, while fixing the uninstall bug on both platforms.

Do not add a distro resolver, a new catalog schema, a desktop entry, a PATH command, or ARM64 support. Do not run Compass as a service, install host packages, elevate privileges, or disable the Electron sandbox.

## Archive Choice

Use only the official standard-edition `mongodb-compass-<version>-linux-x64.tar.gz` from `mongodb-js/compass` GitHub Releases. The upstream release also contains `rhel-x64.tar.gz`, but the existence of a separate build does not establish which distributions require it. Do not select that archive or fall back to it. If the selected archive does not work on a target distro, document the limitation; consider another build only if testing demonstrates a need and a separate change is agreed.

The other approaches considered were automatic selection between Linux and RHEL tarballs, installing native `.deb`/`.rpm` packages, and opening an externally installed Compass. The first adds complexity without an established need, the second mutates the host system, and the third does not provide DevStack-managed installation or updates.

## Catalog and Updater

- Reuse `mongodb-compass`, with `category: tool`, `group_name: database`, and the exact Linux executable basename `MongoDB Compass` from upstream packaging. Omit `cli_file`.
- Match the exact archive name against each stable release's version and retain the asset's official HTTPS download URL and GitHub SHA-256 digest in the existing `versions` and `sha256` maps. Skip drafts, prereleases, releases without a matching asset or valid digest, and all RHEL, non-x64, alternate-edition, signature, and source archives. If the fetch yields no usable versions, fallback may retain only previously validated URL/digest pairs.
- Keep the bundled and staged Linux catalog files byte-identical. Do not publish the new entry into the shared Linux Gist feed during development or verification. Older clients read the same feed, cannot open Linux Compass, and still have the destructive uninstall bug. Before enabling the scheduled publisher to expose this entry, require a rollout that keeps it out of the legacy feed. A valid old cache can also shadow the bundled entry; verify the catalog upgrade path rather than assuming a bundled file update makes Compass visible to existing users.

## Installation, Launch, and Uninstall

- Verify SHA-256 through the existing installer before extraction. Preserve the entire archive tree and companion executable modes. A Linux Compass install without the expected executable must fail instead of reporting success without an executable path.
- In `Apps.openApp`, use a nonblocking, shell-free Linux launch with the absolute executable path and its containing directory as the working directory. Preserve Windows `cmd /c start` and the existing URL-based tool behavior. Report start failures through the existing app error UI.
- Restrict deletion of `AppConfig.dataDir/mongodb` to `appId == 'mongodb'`. Uninstalling Compass must remove only its managed installation, not the server data directory. Reuse the existing Apps and Databases actions keyed by `mongodb-compass`.

## Verification and Release Gates

- Offline updater and catalog tests cover exact archive matching, SHA-256 pairing, fallback behavior, and unchanged Windows selection.
- Installer tests cover the basename with spaces, the full app tree and helper execute modes, checksum mismatch, and a missing main executable. Launcher tests cover both platform branches. Uninstall regression tests use temporary data directories to verify Compass preserves server data and MongoDB Server keeps its intended cleanup behavior.
- Run the analyzer and the full test suite. Inspect the official tarball and test the **same** `linux-x64.tar.gz` under an unprivileged user on representative Ubuntu, Debian, RHEL, and Fedora environments, with the Electron sandbox enabled. Record the distro versions actually tested. The upstream package patterns describe the helpers but do not establish that the portable archive starts with the sandbox enabled in a managed user directory.
- Do not modify host services or security settings, install host packages, or publish container ports. A container-only result is not evidence about a distro's host sandbox policy if the test environment does not reproduce it. Report unverified or incompatible environments and only document support where launch is confirmed.

## Upstream References

- [Compass v1.53.2 release assets](https://github.com/mongodb-js/compass/releases/tag/v1.53.2)
- [Linux tarball naming and packaging](https://github.com/mongodb-js/compass/blob/v1.53.2/packages/hadron-build/src/lib/target.ts)
- [Linux tarball content patterns](https://github.com/mongodb-js/compass/blob/v1.53.2/packages/compass/scripts/patterns/linux_tar-patterns.json)
- [Compass installation and platform requirements](https://www.mongodb.com/docs/compass/install/)
