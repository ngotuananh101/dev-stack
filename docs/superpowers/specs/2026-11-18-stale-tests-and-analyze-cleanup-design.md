# Stale Tests + Analyze Cleanup Design

## Intent

The suite is red (37 failures) and `flutter analyze` reports 112 infos,
and both have been red/noisy since the UI reset sessions of 2026-11-17/18,
not because the app is broken, but because the tests and the imports still
describe the old design. The suite being red hides real regressions: the
pyenv build-deps verification had to diff failures against BASE instead of
trusting green. This change brings the tests and the imports in line with
the UI Ponta already approved part by part, so green means green again.

## Goals

- All 37 failing tests pass, asserting the CURRENT approved UI and behavior.
- `flutter analyze` reports zero issues (no errors, warnings, or infos).
- No production UI change, except fixing the 1px RowActionMenu overflow
  the width-sweep tests catch.

## Non-goals

- No UI redesign or behavior change beyond the 1px overflow fix.
- No new features.
- No changes to tests that already pass.
- No lint suppressions (`// ignore:` comments, `analysis_options.yaml`
  exclusions) to hide the warnings.

## Anti-goals

- Weakening a test to make it pass (tolerating the 1px overflow, asserting
  less, deleting a test that still covers real behavior).
- Reverting any approved UI change to satisfy an old test.

## Constraints

- Tests assert the current approved UI: table headers 10, row cells 10
  except name columns at 12, status chips 8, version tag 8, sidebar 200
  expanded / 64 collapsed with no toggle button (auto-collapse below 960),
  outline buttons (transparent fill), Install Latest hidden until a version
  is picked, Restart only built when the program is running.
- The material_ui swap is a pure import rename: `material_ui` is the same
  Material library under a new name (Flutter 3.47+), already a dependency
  (`material_ui: ^1.10.0`); no API change is expected, and analyze + the
  suite prove it.
- Every test change is verified by running that test file; the whole suite
  and analyze are verified at the end.

## Approaches

1. **Update tests to the current UI + fix the 1px overflow in lib +
   mechanical import swap (chosen).** The tests were written for the old
   design; the UI is as approved. The overflow is a real 1px clip, so it
   is fixed in production code rather than tolerated by the test.
2. Suppress the deprecation + relax the failing tests — rejected: it hides
   the signal Ponta asked to clean, and a future Flutter may remove
   `package:flutter/material.dart` entirely.
3. Revert the UI to match the old tests — rejected: it contradicts Ponta's
   approved per-part changes.

## Decisions (approved by Ponta 2026-11-18)

- Tests follow the current UI; the UI does not move for the tests.
- The 1px RowActionMenu overflow is fixed in production code.
- All `package:flutter/material.dart` imports move to
  `package:material_ui/material_ui.dart`; the unused `rendering.dart`
  import in `terminal_log_view.dart` is removed.

## Left to the builder

- The exact expectation update for each of the 37 tests (read each failing
  test file and its failure message first).
- The exact 1px overflow fix (investigate `planActionColumn` /
  `RowActionMenu` — the column plan looks 1px short at 780/920/980px
  widths).
- Files importing both `material.dart` and `widgets.dart`: after the swap
  the widgets import is redundant (`material_ui` exports widgets) and
  must be removed where analyze flags it; `show`/`hide` combinators on
  the material import are preserved.
- The task split (see the plan).
