# Supervisor & Cronjob Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two first-class DevStack features — a Supervisor that keeps arbitrary long-running processes alive with watchdog auto-restart, and an in-app Cron scheduler that runs arbitrary commands on a 5-field cron schedule — as one PR sharing the Isar/navigation plumbing.

**Architecture:** Two independent feature folders (`lib/features/supervisor`, `lib/features/cron`) mirroring the existing `CliProcessManager` (process-tree spawn + `CircularLogBuffer` + broadcast status stream) and `TunnelManagerService` (service + Isar + `Provider` with `ref.onDispose`) patterns. The cron expression parser is a pure, dependency-free domain class so it can be unit-tested exhaustively without Isar, timers, or processes. Both features register their Isar schemas in the two existing schema lists and add a `NavigationTab` entry.

**Tech Stack:** Flutter / Dart (SDK ^3.10.4), Riverpod 3.4.3 + `riverpod_annotation`/`riverpod_generator` codegen, Isar Plus 1.3.9 (`isar_plus`), `path`, `path_provider`, `lucide_icons_flutter`. Tests: `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-12-supervisor-cron-design.md`

## Global Constraints

- All source code, identifiers, comments, commit messages, and docs are in **English**. No l10n: UI strings are hardcoded English literals.
- Isar Plus: `Isar.open(...)` is **synchronous**; `id == 0` is a real primary key, so every insert MUST explicitly allocate `isar.<collection>.autoIncrement()` before `put` (never rely on a sentinel).
- Both new schemas MUST be registered in `lib/core/database/isar_provider.dart` in **both** schema lists: the initial `Isar.open` (line ~54) and the corruption-recovery re-open (line ~97).
- Process spawn mirrors `CliProcessManager` exactly: POSIX `setsid /bin/sh -c "<command>"` (pid == pgid, so `kill -9 -- -<pid>` kills the tree); Windows `cmd.exe /c "<command>"` with `taskkill /F /T /PID`.
- Log buffer cap is **1000 lines** (`CircularLogBuffer` default). Cron run history is a RAM ring buffer of **20 records per job**.
- Supervisor status enum is `SupervisorStatus { stopped, starting, running, stopping, restarting, fatal }` — in-memory, never persisted.
- Restart backoff is `restartDelaySeconds * 2^(attempts-1)`, capped at **60 s**. `maxRestarts` counts restarts inside a rolling `restartWindowSeconds` window.
- Cron runs **in-app only** (the `Timer` lives in the app process); missed runs while the app was closed are **not** back-filled.
- Shared UI only: `AppButton` (`AppButtonStyle {primary, secondary, success, ghost, outline, danger}`, `AppButtonSize {sm, md, lg}`), `AppIconButton`, `AppModalHeader`, `StatusChip` (`StatusType {stable, restarting, stopped, warning}`), `TerminalLogView`, `AppTextField`, and `modalDimensions(context, ModalSize.{sm,md,lg,xl,full})` (`kModalWidthLg = 720`). Do not introduce new design tokens.
- Codegen: after adding each `@collection` model run `dart run build_runner build --delete-conflicting-outputs` to produce its `.g.dart`.
- Every task ends with `flutter analyze` reporting 0 issues and the named tests passing.

## Review Focus

1. **Cron `nextOccurrence` at a boundary** — a `from` that is itself an exact match, and a `from` on the last minute of a month/year, must return the *next* match strictly after `from` and never loop forever (e.g. `0 0 30 2 *` → `null`). Covered by Task 2 tests.
2. **DOW/DOM OR semantics** — `0 0 1 * 0` must fire on the 1st *or* any Sunday, not only when both coincide. Covered by Task 2 tests.
3. **Watchdog vs. deliberate stop** — a process killed by the user (`stop()`) must settle to `stopped` and never restart, while a crash must restart; the two paths differ only by the `explicitlyStopped` flag. Covered by Task 6 tests.
4. **Restart-storm bound** — a program that crashes immediately, repeatedly, must reach `fatal` after `maxRestarts` within the window and stop spawning. Covered by Task 6 tests.
5. **Cron overlap** — a job whose command outlives its interval must not start a second concurrent run. Covered by Task 7 tests (and the UI reflects it in Task 10).

---

## Task 1: `CronExpression` — parsing and validation

**Files:**
- Create: `lib/features/cron/domain/cron_expression.dart`
- Test: `test/features/cron/domain/cron_expression_parse_test.dart`

**Interfaces:**
- Consumes: nothing (pure Dart; `dart:core` only).
- Produces: `class CronExpression` with:
  - `CronExpression.parse(String expression)` — throws `FormatException` on bad input.
  - `static bool isValid(String expression)`
  - `static String? validate(String expression)` — `null` when ok, else a human message.
  - Fields after parse: `final List<int> minutes; final List<int> hours; final List<int> daysOfMonth; final List<int> months; final List<int> daysOfWeek; final bool domRestricted; final bool dowRestricted;`
  - `String describe()` (Task 3), `DateTime? nextOccurrence(DateTime from)` (Task 2).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/cron/domain/cron_expression_parse_test.dart
import 'package:dev_stack/features/cron/domain/cron_expression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CronExpression parsing', () {
    test('parses every wildcard field', () {
      final e = CronExpression.parse('* * * * *');
      expect(e.minutes.length, 60);
      expect(e.hours.length, 24);
      expect(e.daysOfMonth.length, 31);
      expect(e.months.length, 12);
      expect(e.daysOfWeek.length, 7);
      expect(e.domRestricted, isFalse);
      expect(e.dowRestricted, isFalse);
    });

    test('expands a step list', () {
      final e = CronExpression.parse('*/15 * * * *');
      expect(e.minutes, [0, 15, 30, 45]);
    });

    test('expands a range', () {
      final e = CronExpression.parse('0 9 * * 1-5');
      expect(e.daysOfWeek, [1, 2, 3, 4, 5]);
      expect(e.dowRestricted, isTrue);
    });

    test('expands a comma list combined with a range', () {
      final e = CronExpression.parse('1,15,30-32 * * * *');
      expect(e.minutes, [1, 15, 30, 31, 32]);
    });

    test('range with step', () {
      final e = CronExpression.parse('0-30/10 * * * *');
      expect(e.minutes, [0, 10, 20, 30]);
    });

    test('normalizes day-of-week 7 to Sunday (0)', () {
      final e = CronExpression.parse('0 0 * * 7');
      expect(e.daysOfWeek, [0]);
    });

    test('expands presets', () {
      expect(CronExpression.parse('@hourly').minutes, [0]);
      expect(CronExpression.parse('@daily').hours, [0]);
      expect(CronExpression.parse('@midnight').hours, [0]);
      expect(CronExpression.parse('@weekly').daysOfWeek, [0]);
      expect(CronExpression.parse('@monthly').daysOfMonth, [1]);
      expect(CronExpression.parse('@yearly').months, [1]);
      expect(CronExpression.parse('@annually').months, [1]);
    });

    test('rejects malformed expressions', () {
      for (final bad in [
        '',
        '* * * *',        // 4 fields
        '* * * * * *',    // 6 fields
        '60 * * * *',     // minute out of range
        '* 24 * * *',     // hour out of range
        '* * 0 * *',      // dom must start at 1
        '* * 32 * *',
        '* * * 13 *',
        '* * * * 8',
        'a * * * *',
        '*/0 * * * *',    // zero step
        '5-1 * * * *',    // inverted range
        '@nope',
      ]) {
        expect(CronExpression.isValid(bad), isFalse, reason: bad);
        expect(CronExpression.validate(bad), isNotNull, reason: bad);
      }
    });

    test('validate returns null for a good expression', () {
      expect(CronExpression.validate('*/5 0 1,15 * 1-5'), isNull);
      expect(CronExpression.isValid('@weekly'), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/cron/domain/cron_expression_parse_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:dev_stack/features/cron/domain/cron_expression.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/cron/domain/cron_expression.dart
/// A parsed 5-field cron expression (minute hour day-of-month month
/// day-of-week), with support for `*`, `,`, `-`, `/` and the `@` presets.
///
/// Pure Dart — no Isar, no timers, no processes — so it can be unit-tested
/// exhaustively. Field lists are stored sorted and de-duplicated.
class CronExpression {
  final List<int> minutes;
  final List<int> hours;
  final List<int> daysOfMonth;
  final List<int> months;
  final List<int> daysOfWeek;

  /// Whether the day-of-month / day-of-week field was anything other than `*`.
  /// Vixie cron OR-combines the two only when at least one is restricted.
  final bool domRestricted;
  final bool dowRestricted;

  CronExpression._({
    required this.minutes,
    required this.hours,
    required this.daysOfMonth,
    required this.months,
    required this.daysOfWeek,
    required this.domRestricted,
    required this.dowRestricted,
  });

  static const Map<String, String> _presets = {
    '@hourly': '0 * * * *',
    '@daily': '0 0 * * *',
    '@midnight': '0 0 * * *',
    '@weekly': '0 0 * * 0',
    '@monthly': '0 0 1 * *',
    '@yearly': '0 0 1 1 *',
    '@annually': '0 0 1 1 *',
  };

  factory CronExpression.parse(String expression) {
    final raw = expression.trim();
    if (raw.isEmpty) throw const FormatException('Cron expression is empty');

    final expanded = _presets[raw.toLowerCase()] ?? raw;
    final fields = expanded.split(RegExp(r'\s+'));
    if (fields.length != 5) {
      throw FormatException(
        'Expected 5 fields (minute hour day-of-month month day-of-week), '
        'got ${fields.length}',
      );
    }

    final minutes = _parseField(fields[0], 0, 59, 'minute');
    final hours = _parseField(fields[1], 0, 23, 'hour');
    final daysOfMonth = _parseField(fields[2], 1, 31, 'day-of-month');
    final months = _parseField(fields[3], 1, 12, 'month');
    var daysOfWeek = _parseField(fields[4], 0, 7, 'day-of-week');

    // Standard cron: 0 and 7 both mean Sunday.
    if (daysOfWeek.contains(7)) {
      daysOfWeek = ({...daysOfWeek..remove(7), 0}.toList()..sort());
    }

    return CronExpression._(
      minutes: minutes,
      hours: hours,
      daysOfMonth: daysOfMonth,
      months: months,
      daysOfWeek: daysOfWeek,
      domRestricted: fields[2].trim() != '*',
      dowRestricted: fields[4].trim() != '*',
    );
  }

  /// Expands one field (`*`, `a`, `a-b`, `a,b`, `*/n`, `a-b/n`) into the sorted,
  /// de-duplicated set of matching values within [min]..[max].
  static List<int> _parseField(
    String field,
    int min,
    int max,
    String name,
  ) {
    final values = <int>{};
    for (final part in field.split(',')) {
      final piece = part.trim();
      if (piece.isEmpty) {
        throw FormatException('Empty $name field part');
      }

      var step = 1;
      var range = piece;
      final slash = piece.indexOf('/');
      if (slash >= 0) {
        range = piece.substring(0, slash);
        final stepText = piece.substring(slash + 1);
        step = int.tryParse(stepText) ?? -1;
        if (step <= 0) {
          throw FormatException('Invalid step in $name field: "$piece"');
        }
      }

      int lo;
      int hi;
      if (range == '*') {
        lo = min;
        hi = max;
      } else {
        final dash = range.indexOf('-');
        if (dash >= 0) {
          lo = int.tryParse(range.substring(0, dash)) ?? -1;
          hi = int.tryParse(range.substring(dash + 1)) ?? -1;
          if (lo < 0 || hi < 0 || lo > hi) {
            throw FormatException('Invalid range in $name field: "$piece"');
          }
        } else {
          lo = int.tryParse(range) ?? -1;
          if (lo < 0) {
            throw FormatException('Invalid value in $name field: "$piece"');
          }
          // A bare value with a step (`5/10`) means "5..max step 10".
          hi = slash >= 0 ? max : lo;
        }
      }

      if (lo < min || hi > max) {
        throw FormatException(
          '$name value out of range ($min-$max): "$piece"',
        );
      }

      for (var v = lo; v <= hi; v += step) {
        values.add(v);
      }
    }

    if (values.isEmpty) {
      throw FormatException('$name field matched no values: "$field"');
    }
    final sorted = values.toList()..sort();
    return sorted;
  }

  /// Whether [expression] is a syntactically valid 5-field cron expression.
  static bool isValid(String expression) {
    try {
      CronExpression.parse(expression);
      return true;
    } on FormatException {
      return false;
    }
  }

  /// `null` when [expression] is valid, otherwise a human-readable message.
  static String? validate(String expression) {
    try {
      CronExpression.parse(expression);
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/cron/domain/cron_expression_parse_test.dart`
Expected: PASS (all cases).

- [ ] **Step 5: Commit**

```bash
git add lib/features/cron/domain/cron_expression.dart test/features/cron/domain/cron_expression_parse_test.dart
git commit -m "feat(cron): add 5-field cron expression parser"
```

---

## Task 2: `CronExpression.nextOccurrence` — forward search

**Files:**
- Modify: `lib/features/cron/domain/cron_expression.dart` (add `nextOccurrence`)
- Test: `test/features/cron/domain/cron_expression_next_test.dart`

**Interfaces:**
- Consumes: `CronExpression.parse(...)` and its field lists (Task 1).
- Produces: `DateTime? nextOccurrence(DateTime from)` — the first matching minute **strictly after** `from`, with seconds/milliseconds zeroed; `null` if none within the 4-year horizon.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/cron/domain/cron_expression_next_test.dart
import 'package:dev_stack/features/cron/domain/cron_expression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime at(int y, int mo, int d, int h, int mi) =>
      DateTime(y, mo, d, h, mi, 30, 123); // non-zero s/ms on purpose

  group('CronExpression.nextOccurrence', () {
    test('every minute returns the next minute', () {
      final e = CronExpression.parse('* * * * *');
      expect(e.nextOccurrence(at(2026, 10, 12, 8, 30)),
          DateTime(2026, 10, 12, 8, 31));
    });

    test('is strictly after `from` even when from is an exact match', () {
      final e = CronExpression.parse('30 8 * * *');
      expect(e.nextOccurrence(DateTime(2026, 10, 12, 8, 30)),
          DateTime(2026, 10, 13, 8, 30));
    });

    test('rolls across an hour boundary', () {
      final e = CronExpression.parse('0 * * * *');
      expect(e.nextOccurrence(at(2026, 10, 12, 8, 30)),
          DateTime(2026, 10, 12, 9, 0));
    });

    test('rolls across a day boundary', () {
      final e = CronExpression.parse('0 9 * * *');
      expect(e.nextOccurrence(at(2026, 10, 12, 10, 0)),
          DateTime(2026, 10, 13, 9, 0));
    });

    test('rolls across a month boundary', () {
      final e = CronExpression.parse('0 0 1 * *');
      expect(e.nextOccurrence(at(2026, 10, 12, 0, 0)),
          DateTime(2026, 11, 1, 0, 0));
    });

    test('rolls across a year boundary', () {
      final e = CronExpression.parse('0 0 1 1 *');
      expect(e.nextOccurrence(at(2026, 10, 12, 0, 0)),
          DateTime(2027, 1, 1, 0, 0));
    });

    test('weekday range only fires Mon-Fri', () {
      final e = CronExpression.parse('0 9 * * 1-5');
      // 2026-10-12 is a Monday; from Sat 10-10 00:00 the next hit is Mon 10-12.
      expect(e.nextOccurrence(at(2026, 10, 10, 0, 0)),
          DateTime(2026, 10, 12, 9, 0));
    });

    test('DOW 7 and 0 both mean Sunday', () {
      final e = CronExpression.parse('0 12 * * 7');
      // 2026-10-12 is Monday; next Sunday is 2026-10-18.
      expect(e.nextOccurrence(at(2026, 10, 12, 0, 0)),
          DateTime(2026, 10, 18, 12, 0));
    });

    test('DOM and DOW are OR-combined when both are restricted', () {
      // "0 0 1 * 0" = the 1st of the month OR any Sunday.
      final e = CronExpression.parse('0 0 1 * 0');
      // From Mon 2026-10-12: the next Sunday (10-18) comes before 11-01.
      expect(e.nextOccurrence(at(2026, 10, 12, 0, 0)),
          DateTime(2026, 10, 18, 0, 0));
    });

    test('a schedule that can never match returns null', () {
      final e = CronExpression.parse('0 0 30 2 *'); // Feb 30
      expect(e.nextOccurrence(at(2026, 10, 12, 0, 0)), isNull);
    });

    test('preset @hourly fires on the hour', () {
      final e = CronExpression.parse('@hourly');
      expect(e.nextOccurrence(at(2026, 10, 12, 8, 30)),
          DateTime(2026, 10, 12, 9, 0));
    });

    test('@weekly fires at Sunday midnight', () {
      final e = CronExpression.parse('@weekly');
      expect(e.nextOccurrence(at(2026, 10, 12, 8, 0)),
          DateTime(2026, 10, 18, 0, 0));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/cron/domain/cron_expression_next_test.dart`
Expected: FAIL — `The method 'nextOccurrence' isn't defined for the type 'CronExpression'`.

- [ ] **Step 3: Write minimal implementation**

Add to `lib/features/cron/domain/cron_expression.dart` (inside `CronExpression`):

```dart
  /// The first matching minute strictly after [from].
  ///
  /// Scans forward one minute at a time from `from + 1 minute`, bounded by a
  /// 4-year horizon so an unsatisfiable schedule (e.g. `0 0 30 2 *`) returns
  /// `null` instead of looping forever.
  DateTime? nextOccurrence(DateTime from) {
    final start = DateTime(from.year, from.month, from.day, from.hour, from.minute)
        .add(const Duration(minutes: 1));
    final horizon = DateTime(start.year + 4, start.month, start.day);

    var candidate = start;
    while (candidate.isBefore(horizon)) {
      if (_matches(candidate)) return candidate;
      candidate = candidate.add(const Duration(minutes: 1));
    }
    return null;
  }

  bool _matches(DateTime t) {
    if (!minutes.contains(t.minute)) return false;
    if (!hours.contains(t.hour)) return false;
    if (!months.contains(t.month)) return false;

    final domHit = daysOfMonth.contains(t.day);
    // DateTime.weekday is 1=Mon..7=Sun; cron is 0=Sun..6=Sat.
    final cronDow = t.weekday % 7;
    final dowHit = daysOfWeek.contains(cronDow);

    // Vixie cron: when both DOM and DOW are restricted, a day matches if
    // EITHER matches. When only one is restricted, only that one gates.
    if (domRestricted && dowRestricted) return domHit || dowHit;
    if (domRestricted) return domHit;
    if (dowRestricted) return dowHit;
    return true;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/cron/domain/cron_expression_next_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/cron/domain/cron_expression.dart test/features/cron/domain/cron_expression_next_test.dart
git commit -m "feat(cron): compute next occurrence for a cron expression"
```

---

## Task 3: `CronExpression.describe` — human-readable summary

**Files:**
- Modify: `lib/features/cron/domain/cron_expression.dart` (add `describe`)
- Test: `test/features/cron/domain/cron_expression_describe_test.dart`

**Interfaces:**
- Consumes: the parsed field lists (Task 1).
- Produces: `String describe()` — a short English summary for the table/form.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/cron/domain/cron_expression_describe_test.dart
import 'package:dev_stack/features/cron/domain/cron_expression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CronExpression.describe', () {
    test('every minute', () {
      expect(CronExpression.parse('* * * * *').describe(), 'Every minute');
    });

    test('every N minutes', () {
      expect(CronExpression.parse('*/5 * * * *').describe(),
          'Every 5 minutes');
    });

    test('at a specific time', () {
      expect(CronExpression.parse('30 8 * * *').describe(), 'At 08:30');
    });

    test('hourly', () {
      expect(CronExpression.parse('@hourly').describe(), 'Every hour');
    });

    test('daily', () {
      expect(CronExpression.parse('@daily').describe(), 'At 00:00');
    });

    test('weekly names the weekday', () {
      expect(CronExpression.parse('@weekly').describe(), 'At 00:00 on Sunday');
    });

    test('monthly', () {
      expect(CronExpression.parse('@monthly').describe(),
          'At 00:00 on day 1');
    });

    test('yearly', () {
      expect(CronExpression.parse('@yearly').describe(),
          'At 00:00 on Jan 1');
    });

    test('weekday range', () {
      expect(CronExpression.parse('0 9 * * 1-5').describe(),
          'At 09:00 on Mon-Fri');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/cron/domain/cron_expression_describe_test.dart`
Expected: FAIL — `The method 'describe' isn't defined for the type 'CronExpression'`.

- [ ] **Step 3: Write minimal implementation**

Add to `lib/features/cron/domain/cron_expression.dart` (inside `CronExpression`):

```dart
  static const List<String> _weekdayNames = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday',
    'Thursday', 'Friday', 'Saturday',
  ];
  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _two(int v) => v.toString().padLeft(2, '0');

  /// A short human-readable summary, e.g. "Every 5 minutes" or
  /// "At 09:00 on Mon-Fri". Deliberately covers the common shapes; unusual
  /// combinations fall back to a generic time/date summary.
  String describe() {
    final everyMinute = minutes.length == 60;
    final everyHour = hours.length == 24;

    // Time-of-day phrase (only meaningful when a single time is pinned).
    String? timePhrase;
    if (minutes.length == 1 && hours.length == 1) {
      timePhrase = 'At ${_two(hours.first)}:${_two(minutes.first)}';
    }

    final dayPart = _describeDays();

    if (everyMinute) {
      return dayPart == null ? 'Every minute' : 'Every minute $dayPart';
    }
    if (minutes.length == 1 && minutes.first == 0 && everyHour) {
      return dayPart == null ? 'Every hour' : 'Every hour $dayPart';
    }
    // Pure "every N minutes" within the hour, no other restriction.
    if (hours.length == 24 && dayPart == null) {
      if (minutes.length == 1) return 'At minute ${minutes.first}';
      final step = minutes.length > 1 ? minutes[1] - minutes[0] : 0;
      final isStepped = minutes.first == 0 &&
          step > 0 &&
          List.generate(minutes.length, (i) => i * step).every(
                (v) => minutes.contains(v),
              );
      if (isStepped) return 'Every $step minutes';
    }

    if (timePhrase != null) {
      return dayPart == null ? timePhrase : '$timePhrase $dayPart';
    }
    if (dayPart != null) {
      return dayPart[0].toUpperCase() + dayPart.substring(1);
    }
    return 'Custom schedule';
  }

  /// Returns a day qualifier such as "on Mon-Fri", "on day 1", or
  /// "on Sunday", or `null` when the schedule runs every day.
  String? _describeDays() {
    final everyDom = daysOfMonth.length == 31;
    final everyDow = daysOfWeek.length == 7;

    if (everyDom && everyDow) return null;

    // Month restriction first (yearly-ish).
    if (months.length == 1 && daysOfMonth.length == 1) {
      return 'on ${_monthNames[months.first - 1]} ${daysOfMonth.first}';
    }

    if (!everyDom && daysOfMonth.length == 1) {
      return 'on day ${daysOfMonth.first}';
    }

    if (!everyDow) {
      if (daysOfWeek.length == 1) {
        return 'on ${_weekdayNames[daysOfWeek.first]}';
      }
      // Contiguous range like 1-5 → "Mon-Fri".
      final contiguous = daysOfWeek.length > 1 &&
          daysOfWeek.last - daysOfWeek.first == daysOfWeek.length - 1;
      if (contiguous) {
        final a = _weekdayNames[daysOfWeek.first].substring(0, 3);
        final b = _weekdayNames[daysOfWeek.last].substring(0, 3);
        return 'on $a-$b';
      }
    }

    if (!everyDom) return 'on days ${daysOfMonth.join(', ')}';
    return null;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/cron/domain/cron_expression_describe_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/cron/domain/cron_expression.dart test/features/cron/domain/cron_expression_describe_test.dart
git commit -m "feat(cron): add human-readable cron description"
```

---

## Task 4: `CronJob` model + Isar schema registration

**Files:**
- Create: `lib/features/cron/domain/cron_job.dart`
- Modify: `lib/core/database/isar_provider.dart` (both schema lists)
- Test: `test/features/cron/domain/cron_job_test.dart`

**Interfaces:**
- Consumes: `isar_plus`.
- Produces: `@collection class CronJob` with fields
  `int id`, `String name`, `String schedule`, `String command`,
  `String workingDir`, `bool enabled = true`, `DateTime? lastRunAt`,
  `String? lastStatus`, `int? lastExitCode`, `DateTime? createdAt`;
  a named constructor with all-optional fields; `Isar.open` now includes
  `CronJobSchema`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/cron/domain/cron_job_test.dart
import 'package:dev_stack/features/cron/domain/cron_job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults are sensible for a new job', () {
    final job = CronJob(name: 'Backup', schedule: '@daily', command: 'echo hi');
    expect(job.id, 0);
    expect(job.enabled, isTrue);
    expect(job.workingDir, '');
    expect(job.lastRunAt, isNull);
    expect(job.lastStatus, isNull);
    expect(job.lastExitCode, isNull);
  });

  test('carries all fields through', () {
    final job = CronJob(
      id: 7,
      name: 'Cleanup',
      schedule: '*/5 * * * *',
      command: 'rm -rf tmp',
      workingDir: '/tmp',
      enabled: false,
      lastStatus: 'success',
      lastExitCode: 0,
    );
    expect(job.id, 7);
    expect(job.name, 'Cleanup');
    expect(job.schedule, '*/5 * * * *');
    expect(job.command, 'rm -rf tmp');
    expect(job.workingDir, '/tmp');
    expect(job.enabled, isFalse);
    expect(job.lastStatus, 'success');
    expect(job.lastExitCode, 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/cron/domain/cron_job_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:dev_stack/features/cron/domain/cron_job.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/cron/domain/cron_job.dart
import 'package:isar_plus/isar_plus.dart';

part 'cron_job.g.dart';

@collection
class CronJob {
  int id = 0; // Primary key. Set via collection.autoIncrement() on insert.

  @Index(unique: true)
  late String name;

  late String schedule; // "*/5 * * * *" or "@daily"
  late String command;
  String workingDir = '';
  bool enabled = true;

  DateTime? lastRunAt;
  String? lastStatus; // 'success' | 'failed' | 'running'
  int? lastExitCode;
  DateTime? createdAt;

  CronJob({
    this.id = 0,
    required this.name,
    required this.schedule,
    required this.command,
    this.workingDir = '',
    this.enabled = true,
    this.lastRunAt,
    this.lastStatus,
    this.lastExitCode,
    this.createdAt,
  });
}
```

- [ ] **Step 4: Generate the Isar schema**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: creates `lib/features/cron/domain/cron_job.g.dart` with `CronJobSchema`. No errors.

- [ ] **Step 5: Register the schema in both lists**

In `lib/core/database/isar_provider.dart`:
- Add `import '../../features/cron/domain/cron_job.dart';` next to the other feature imports.
- Add `CronJobSchema,` to the `schemas:` list in `_openDatabase`'s initial `Isar.open` (line ~54) **and** to the list in the corruption-recovery `Isar.open` (line ~97).

- [ ] **Step 6: Run test + analyze**

Run: `flutter test test/features/cron/domain/cron_job_test.dart && flutter analyze lib/features/cron lib/core/database/isar_provider.dart`
Expected: PASS, 0 issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/cron/domain/cron_job.dart lib/features/cron/domain/cron_job.g.dart lib/core/database/isar_provider.dart test/features/cron/domain/cron_job_test.dart
git commit -m "feat(cron): add CronJob model and register its Isar schema"
```

---

## Task 5: `SupervisorProgram` model + Isar schema registration

**Files:**
- Create: `lib/features/supervisor/domain/supervisor_program.dart`
- Create: `lib/features/supervisor/domain/supervisor_status.dart`
- Modify: `lib/core/database/isar_provider.dart` (both schema lists)
- Test: `test/features/supervisor/domain/supervisor_program_test.dart`

**Interfaces:**
- Consumes: `isar_plus`.
- Produces:
  - `enum SupervisorStatus { stopped, starting, running, stopping, restarting, fatal }`
  - `@collection class SupervisorProgram` with fields
    `int id`, `String name`, `String command`, `String workingDir`,
    `String environmentJson = '{}'`, `bool autoStart = false`,
    `bool autoRestart = true`, `int maxRestarts = 5`,
    `int restartWindowSeconds = 60`, `int restartDelaySeconds = 2`,
    `bool enabled = true`, `DateTime? createdAt`;
    `Map<String, String> envVars()` decodes `environmentJson`;
    `Isar.open` now includes `SupervisorProgramSchema`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/supervisor/domain/supervisor_program_test.dart
import 'package:dev_stack/features/supervisor/domain/supervisor_program.dart';
import 'package:dev_stack/features/supervisor/domain/supervisor_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults keep a program supervised and restartable', () {
    final p = SupervisorProgram(name: 'Queue', command: 'php artisan queue:work');
    expect(p.id, 0);
    expect(p.autoStart, isFalse);
    expect(p.autoRestart, isTrue);
    expect(p.maxRestarts, 5);
    expect(p.restartWindowSeconds, 60);
    expect(p.restartDelaySeconds, 2);
    expect(p.enabled, isTrue);
    expect(p.environmentJson, '{}');
    expect(p.envVars(), isEmpty);
  });

  test('envVars decodes the JSON blob', () {
    final p = SupervisorProgram(
      name: 'Worker',
      command: 'node worker.js',
      environmentJson: '{"QUEUE":"high","DEBUG":"1"}',
    );
    expect(p.envVars(), {'QUEUE': 'high', 'DEBUG': '1'});
  });

  test('envVars tolerates malformed JSON', () {
    final p = SupervisorProgram(
      name: 'Bad',
      command: 'x',
      environmentJson: 'not json',
    );
    expect(p.envVars(), isEmpty);
  });

  test('status enum has the expected members', () {
    expect(SupervisorStatus.values, [
      SupervisorStatus.stopped,
      SupervisorStatus.starting,
      SupervisorStatus.running,
      SupervisorStatus.stopping,
      SupervisorStatus.restarting,
      SupervisorStatus.fatal,
    ]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/supervisor/domain/supervisor_program_test.dart`
Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/supervisor/domain/supervisor_status.dart
/// Live state of a supervised program. In-memory only — never persisted.
enum SupervisorStatus {
  stopped,
  starting,
  running,
  stopping,
  restarting,
  fatal,
}
```

```dart
// lib/features/supervisor/domain/supervisor_program.dart
import 'dart:convert';
import 'package:isar_plus/isar_plus.dart';

part 'supervisor_program.g.dart';

@collection
class SupervisorProgram {
  int id = 0; // Primary key. Set via collection.autoIncrement() on insert.

  @Index(unique: true)
  late String name;

  late String command; // e.g. "php artisan queue:work"
  String workingDir = '';

  /// Extra environment variables, merged over the parent environment. Stored
  /// as a flat JSON object following the existing `*Json` convention.
  String environmentJson = '{}';

  bool autoStart = false; // start when the app opens
  bool autoRestart = true; // watchdog on/off
  int maxRestarts = 5; // max restarts inside restartWindowSeconds
  int restartWindowSeconds = 60;
  int restartDelaySeconds = 2; // base backoff delay
  bool enabled = true; // master switch (disabled = never starts)

  DateTime? createdAt;

  SupervisorProgram({
    this.id = 0,
    required this.name,
    required this.command,
    this.workingDir = '',
    this.environmentJson = '{}',
    this.autoStart = false,
    this.autoRestart = true,
    this.maxRestarts = 5,
    this.restartWindowSeconds = 60,
    this.restartDelaySeconds = 2,
    this.enabled = true,
    this.createdAt,
  });

  /// Decodes [environmentJson] into a map, returning an empty map when the
  /// stored blob is malformed (a corrupt record must not crash the watchdog).
  Map<String, String> envVars() {
    try {
      final decoded = jsonDecode(environmentJson);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {
      // Fall through to the empty map.
    }
    return const {};
  }
}
```

- [ ] **Step 4: Generate the Isar schema**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: creates `lib/features/supervisor/domain/supervisor_program.g.dart` with `SupervisorProgramSchema`.

- [ ] **Step 5: Register the schema in both lists**

In `lib/core/database/isar_provider.dart`:
- Add `import '../../features/supervisor/domain/supervisor_program.dart';`.
- Add `SupervisorProgramSchema,` to **both** `schemas:` lists (initial open ~line 54, recovery re-open ~line 97).

- [ ] **Step 6: Run test + analyze**

Run: `flutter test test/features/supervisor/domain/supervisor_program_test.dart && flutter analyze lib/features/supervisor lib/core/database/isar_provider.dart`
Expected: PASS, 0 issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/supervisor/domain/ lib/core/database/isar_provider.dart test/features/supervisor/domain/supervisor_program_test.dart
git commit -m "feat(supervisor): add SupervisorProgram model and register its Isar schema"
```

---

## Task 6: `SupervisorManager` — spawn, tree-kill, watchdog auto-restart

**Files:**
- Create: `lib/features/supervisor/data/supervisor_manager.dart`
- Test: `test/features/supervisor/data/supervisor_manager_test.dart`

**Interfaces:**
- Consumes: `SupervisorProgram`, `SupervisorStatus` (Task 5), `CircularLogBuffer` (from `lib/features/sites/data/cli_process_manager.dart`), `AppConfig`, `Isar`.
- Produces:
  - `abstract class SupervisedProcess { int get pid; Stream<List<int>> get stdout; Stream<List<int>> get stderr; Future<int> get exitCode; }`
  - `typedef SupervisorSpawner = Future<SupervisedProcess> Function(SupervisorProgram program);`
  - `typedef SupervisorTreeKiller = Future<void> Function(int pid);`
  - `typedef SupervisorDelay = Future<void> Function(Duration duration);`
  - `class SupervisorManager` with:
    `SupervisorManager({String? logsDirectory, Isar? isar, Isar? Function()? isarResolver, SupervisorSpawner? spawner, SupervisorTreeKiller? treeKiller, SupervisorDelay? delay})`
    (the two Isar parameters are mutually exclusive: `isar` pins a fixed
    database for tests, `isarResolver` resolves one lazily in production),
    `Future<bool> start(SupervisorProgram program)`, `Future<bool> stop(int programId)`,
    `Future<bool> restart(SupervisorProgram program)`, `Future<void> startAll()`,
    `Future<void> startAutoStart()`, `Future<void> stopAll()`, `bool isRunning(int)`,
    `int? getPid(int)`, `SupervisorStatus statusOf(int)`, `List<String> getLogBuffer(int)`,
    `Stream<String> getLogStream(int)`, `void clearLogs(int)`, `Stream<int> get statusStream`,
    `void dispose()`.
  - `final supervisorManagerProvider = Provider<SupervisorManager>(...)` with `ref.onDispose`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/supervisor/data/supervisor_manager_test.dart
import 'dart:async';
import 'dart:io';

import 'package:dev_stack/features/supervisor/data/supervisor_manager.dart';
import 'package:dev_stack/features/supervisor/domain/supervisor_program.dart';
import 'package:dev_stack/features/supervisor/domain/supervisor_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// A controllable stand-in for a spawned process. The test drives its exit
/// code explicitly, so watchdog behaviour is deterministic.
class _FakeProcess implements SupervisedProcess {
  @override
  final int pid;
  final _exit = Completer<int>();
  _FakeProcess(this.pid);

  @override
  Stream<List<int>> get stdout => const Stream.empty();
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  Future<int> get exitCode => _exit.future;

  void exit(int code) {
    if (!_exit.isCompleted) _exit.complete(code);
  }
}

class _FakeSpawner {
  final List<_FakeProcess> spawned = [];
  int _nextPid = 100;

  Future<SupervisedProcess> spawn(SupervisorProgram program) async {
    final p = _FakeProcess(_nextPid++);
    spawned.add(p);
    return p;
  }
}

void main() {
  late Directory tempDir;
  late _FakeSpawner spawner;
  late List<int> killedPids;
  late SupervisorManager manager;

  SupervisorProgram program({
    int maxRestarts = 5,
    bool autoRestart = true,
    bool enabled = true,
  }) =>
      SupervisorProgram(
        id: 1,
        name: 'Queue',
        command: 'php artisan queue:work',
        workingDir: tempDir.path,
        autoRestart: autoRestart,
        maxRestarts: maxRestarts,
        restartWindowSeconds: 60,
        restartDelaySeconds: 0,
        enabled: enabled,
      );

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('sup_test_');
    spawner = _FakeSpawner();
    killedPids = [];
    manager = SupervisorManager(
      logsDirectory: tempDir.path,
      spawner: spawner.spawn,
      treeKiller: (pid) async => killedPids.add(pid),
      // Zero-delay backoff keeps the watchdog tests instant.
      delay: (_) async {},
    );
  });

  tearDown(() async {
    await manager.stopAll();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('start spawns once and reports running with a pid', () async {
    expect(await manager.start(program()), isTrue);
    expect(manager.isRunning(1), isTrue);
    expect(manager.getPid(1), 100);
    expect(manager.statusOf(1), SupervisorStatus.running);
    expect(spawner.spawned.length, 1);
  });

  test('a crash with autoRestart respawns the program', () async {
    await manager.start(program());
    spawner.spawned.first.exit(1);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(spawner.spawned.length, 2);
    expect(manager.statusOf(1), SupervisorStatus.running);
    expect(manager.isRunning(1), isTrue);
  });

  test('an explicit stop does not restart', () async {
    await manager.start(program());
    await manager.stop(1);
    spawner.spawned.first.exit(1);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(spawner.spawned.length, 1);
    expect(manager.statusOf(1), SupervisorStatus.stopped);
    expect(manager.isRunning(1), isFalse);
    expect(killedPids, [100]);
  });

  test('autoRestart=false settles at stopped on crash', () async {
    await manager.start(program(autoRestart: false));
    spawner.spawned.first.exit(1);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(spawner.spawned.length, 1);
    expect(manager.statusOf(1), SupervisorStatus.stopped);
  });

  test('a disabled program never starts', () async {
    expect(await manager.start(program(enabled: false)), isFalse);
    expect(spawner.spawned, isEmpty);
  });

  test('exceeding maxRestarts gives up with fatal', () async {
    await manager.start(program(maxRestarts: 2));
    // Crash the initial process and every respawn until the watchdog gives up.
    for (var i = 0; i < 4; i++) {
      if (i < spawner.spawned.length) {
        spawner.spawned[i].exit(1);
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(manager.statusOf(1), SupervisorStatus.fatal);
    // 1 initial + 2 allowed restarts = 3 spawns, then it stops spawning.
    expect(spawner.spawned.length, 3);
  });

  test('statusStream emits the program id on change', () async {
    final seen = <int>[];
    final sub = manager.statusStream.listen(seen.add);
    await manager.start(program());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await sub.cancel();
    expect(seen, contains(1));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/supervisor/data/supervisor_manager_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:dev_stack/features/supervisor/data/supervisor_manager.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/supervisor/data/supervisor_manager.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_plus/isar_plus.dart';
import 'package:path/path.dart' as p;

import '../../../core/config/app_config.dart';
import '../../../core/database/isar_provider.dart';
import '../../../core/services/log_service.dart';
import '../../sites/data/cli_process_manager.dart' show CircularLogBuffer;
import '../domain/supervisor_program.dart';
import '../domain/supervisor_status.dart';

export '../domain/supervisor_status.dart';

/// A spawned supervised process. Abstracted so tests can drive its exit code
/// without spawning anything real.
abstract class SupervisedProcess {
  int get pid;
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  Future<int> get exitCode;
}

class _RealSupervisedProcess implements SupervisedProcess {
  final Process _process;
  _RealSupervisedProcess(this._process);

  @override
  int get pid => _process.pid;
  @override
  Stream<List<int>> get stdout => _process.stdout;
  @override
  Stream<List<int>> get stderr => _process.stderr;
  @override
  Future<int> get exitCode => _process.exitCode;
}

/// Spawns a program's command. The default implementation mirrors
/// `CliProcessManager` (setsid on POSIX, cmd.exe on Windows).
typedef SupervisorSpawner = Future<SupervisedProcess> Function(
  SupervisorProgram program,
);

/// Terminates an entire process tree rooted at [pid].
typedef SupervisorTreeKiller = Future<void> Function(int pid);

/// Sleeps for [duration]. Injected so tests can run the backoff instantly.
typedef SupervisorDelay = Future<void> Function(Duration duration);

/// Bookkeeping for one supervised process and its output sinks.
class ManagedSupervisorProcess {
  final int programId;
  final SupervisedProcess process;
  final CircularLogBuffer logBuffer;
  final StreamController<String> streamController;
  final IOSink logFileSink;
  bool running = true;

  /// Set by [SupervisorManager.stop] / [stopAll] / [dispose] so the exit
  /// handler can tell a deliberate stop from a crash.
  bool explicitlyStopped = false;

  ManagedSupervisorProcess({
    required this.programId,
    required this.process,
    required this.logBuffer,
    required this.streamController,
    required this.logFileSink,
  });
}

final supervisorManagerProvider = Provider<SupervisorManager>((ref) {
  final manager = SupervisorManager(
    // Late-bound on purpose. The database opens asynchronously, so a snapshot
    // taken here would be null forever; and `ref.watch(isarProvider)` would
    // rebuild the manager the moment the DB lands, reaping any process already
    // started. Resolving at call time keeps one manager for the app's life.
    isarResolver: () => ref.read(isarProvider).value,
  );
  ref.onDispose(() => manager.dispose());
  return manager;
});

/// Keeps arbitrary long-running processes alive, restarting them when they
/// crash unless the user asked them to stop.
///
/// Mirrors `CliProcessManager` for spawn/tee/status, and adds a watchdog:
/// on a crash it restarts after an exponential backoff, up to [maxRestarts]
/// within a rolling window, then gives up and reports `fatal`.
class SupervisorManager {
  final String? logsDirectory;
  final Isar? Function() _isarResolver;
  final SupervisorSpawner _spawner;
  final SupervisorTreeKiller _treeKiller;
  final SupervisorDelay _delay;

  final Map<int, ManagedSupervisorProcess> _processes = {};
  final Map<int, SupervisorStatus> _statuses = {};
  final Map<int, List<DateTime>> _restartTimes = {};
  final StreamController<int> _statusController =
      StreamController<int>.broadcast();

  /// [isar] pins a fixed database (tests); [isarResolver] resolves one lazily
  /// (production), so a manager created before the async open still sees it.
  SupervisorManager({
    this.logsDirectory,
    Isar? isar,
    Isar? Function()? isarResolver,
    SupervisorSpawner? spawner,
    SupervisorTreeKiller? treeKiller,
    SupervisorDelay? delay,
  })  : _isarResolver = isarResolver ?? (isar != null ? () => isar : () => null),
        _spawner = spawner ?? _defaultSpawn,
        _treeKiller = treeKiller ?? _defaultTreeKill,
        _delay = delay ?? Future<void>.delayed;

  Isar? get _isar => _isarResolver();

  Stream<int> get statusStream => _statusController.stream;

  void _notifyStatus(int programId) {
    if (!_statusController.isClosed) _statusController.add(programId);
  }

  SupervisorStatus statusOf(int programId) =>
      _statuses[programId] ?? SupervisorStatus.stopped;

  bool isRunning(int programId) => _processes[programId]?.running ?? false;

  int? getPid(int programId) => _processes[programId]?.process.pid;

  List<String> getLogBuffer(int programId) =>
      _processes[programId]?.logBuffer.lines ?? [];

  Stream<String> getLogStream(int programId) =>
      _processes[programId]?.streamController.stream ?? const Stream.empty();

  void clearLogs(int programId) => _processes[programId]?.logBuffer.clear();

  Map<String, String> _buildEnvironment(SupervisorProgram program) {
    final env = Map<String, String>.from(Platform.environment);
    env.addAll(program.envVars());
    return env;
  }

  static Future<SupervisedProcess> _defaultSpawn(
    SupervisorProgram program,
  ) async {
    if (Platform.isWindows) {
      return _RealSupervisedProcess(await Process.start(
        'cmd.exe',
        ['/c', program.command],
        workingDirectory: program.workingDir,
      ));
    }
    try {
      // setsid makes the child its own process-group leader (pid == pgid), so
      // `kill -9 -- -<pid>` addresses the whole tree.
      return _RealSupervisedProcess(await Process.start(
        'setsid',
        ['/bin/sh', '-c', program.command],
        workingDirectory: program.workingDir,
      ));
    } catch (_) {
      return _RealSupervisedProcess(await Process.start(
        '/bin/sh',
        ['-c', program.command],
        workingDirectory: program.workingDir,
      ));
    }
  }

  static Future<void> _defaultTreeKill(int pid) async {
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/F', '/T', '/PID', '$pid']);
      } else {
        await Process.run('kill', ['-TERM', '-$pid']);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await Process.run('kill', ['-9', '-$pid']);
        await Process.run('kill', ['-9', '$pid']);
      }
    } catch (_) {
      // Best-effort: the process may already be gone.
    }
  }

  /// Starts [program]. Returns `false` when the program is disabled or its
  /// command is empty; returns `true` when it is already running.
  ///
  /// [isRestart] is internal: a watchdog respawn keeps the rolling restart
  /// window, while a user-initiated start resets it.
  Future<bool> start(SupervisorProgram program, {bool isRestart = false}) async {
    if (!program.enabled) return false;
    if (program.command.trim().isEmpty) return false;
    if (isRunning(program.id)) return true;

    final workDir = Directory(program.workingDir);
    if (program.workingDir.isNotEmpty && !workDir.existsSync()) {
      throw StateError('Working directory does not exist: ${program.workingDir}');
    }

    if (_processes.containsKey(program.id)) {
      await _remove(program.id);
    }

    _statuses[program.id] = SupervisorStatus.starting;
    _notifyStatus(program.id);

    final logBase = logsDirectory ?? p.join(AppConfig.baseDir, 'logs');
    final logDir = Directory(p.join(logBase, 'supervisor'));
    if (!logDir.existsSync()) logDir.createSync(recursive: true);
    final sink = File(p.join(logDir.path, '${program.name}.log'))
        .openWrite(mode: FileMode.append);

    final buffer = CircularLogBuffer();
    final controller = StreamController<String>.broadcast();

    SupervisedProcess process;
    try {
      process = await _spawner(program);
    } catch (e) {
      await sink.flush();
      await sink.close();
      _statuses[program.id] = SupervisorStatus.fatal;
      _notifyStatus(program.id);
      AppLogger.error('Failed to start supervised program ${program.name}: $e');
      return false;
    }

    final managed = ManagedSupervisorProcess(
      programId: program.id,
      process: process,
      logBuffer: buffer,
      streamController: controller,
      logFileSink: sink,
    );
    _processes[program.id] = managed;

    void handleLine(String line) {
      buffer.add(line);
      if (!controller.isClosed) controller.add(line);
      try {
        sink.writeln('[${DateTime.now().toIso8601String()}] $line');
      } catch (_) {
        // Sink already closed; the in-memory buffer still holds the line.
      }
    }

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(handleLine);
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((e) => handleLine('[ERROR] $e'));

    process.exitCode.then(
      (code) => unawaited(_handleExit(program, managed, code)),
      onError: (_) => unawaited(_handleExit(program, managed, null)),
    );

    _statuses[program.id] = SupervisorStatus.running;
    _notifyStatus(program.id);
    if (!isRestart) {
      _restartTimes.remove(program.id);
    }
    return true;
  }

  /// Watchdog: decide whether to respawn after [managed]'s process exited.
  Future<void> _handleExit(
    SupervisorProgram program,
    ManagedSupervisorProcess managed,
    int? code,
  ) async {
    managed.running = false;
    final line = code == null
        ? '[Process exited unexpectedly]'
        : '[Process exited with code $code]';
    managed.logBuffer.add(line);
    if (!managed.streamController.isClosed) managed.streamController.add(line);

    // A deliberate stop settles at stopped and never restarts.
    if (managed.explicitlyStopped) {
      _statuses[program.id] = SupervisorStatus.stopped;
      _notifyStatus(program.id);
      return;
    }

    if (!program.enabled || !program.autoRestart) {
      _statuses[program.id] = SupervisorStatus.stopped;
      _notifyStatus(program.id);
      return;
    }

    final now = DateTime.now();
    final times = _restartTimes.putIfAbsent(program.id, () => []);
    final windowStart =
        now.subtract(Duration(seconds: program.restartWindowSeconds));
    times.removeWhere((t) => t.isBefore(windowStart));
    times.add(now);

    if (times.length > program.maxRestarts) {
      _statuses[program.id] = SupervisorStatus.fatal;
      final msg =
          'Exceeded max restarts (${program.maxRestarts}) in '
          '${program.restartWindowSeconds}s — giving up';
      managed.logBuffer.add(msg);
      if (!managed.streamController.isClosed) managed.streamController.add(msg);
      _notifyStatus(program.id);
      return;
    }

    // Exponential backoff: base * 2^(attempt-1), capped at 60 s.
    final attempt = times.length > 10 ? 10 : times.length;
    var seconds = program.restartDelaySeconds * (1 << (attempt - 1));
    if (seconds > 60) seconds = 60;
    if (seconds < 0) seconds = 0;

    _statuses[program.id] = SupervisorStatus.restarting;
    _notifyStatus(program.id);

    if (seconds > 0) {
      await _delay(Duration(seconds: seconds));
    }
    // The program may have been stopped or disabled while we waited.
    if (managed.explicitlyStopped || !program.enabled) {
      _statuses[program.id] = SupervisorStatus.stopped;
      _notifyStatus(program.id);
      return;
    }
    await start(program, isRestart: true);
  }

  Future<bool> stop(int programId) async {
    final managed = _processes[programId];
    if (managed == null) {
      _statuses[programId] = SupervisorStatus.stopped;
      _notifyStatus(programId);
      return false;
    }
    managed.explicitlyStopped = true;
    _statuses[programId] = SupervisorStatus.stopping;
    _notifyStatus(programId);
    await _treeKiller(managed.process.pid);
    await _remove(programId);
    _restartTimes.remove(programId);
    _statuses[programId] = SupervisorStatus.stopped;
    _notifyStatus(programId);
    return true;
  }

  Future<bool> restart(SupervisorProgram program) async {
    await stop(program.id);
    return start(program);
  }

  /// Starts every enabled program stored in Isar.
  Future<void> startAll() async {
    final isar = _isar;
    if (isar == null) return;
    final programs = isar.supervisorPrograms.where().findAll();
    for (final program in programs) {
      if (!program.enabled) continue;
      try {
        await start(program);
      } catch (e) {
        AppLogger.error('Failed to start ${program.name}: $e');
      }
    }
  }

  /// Starts only the programs marked `autoStart` (used on app launch).
  Future<void> startAutoStart() async {
    final isar = _isar;
    if (isar == null) return;
    final programs = isar.supervisorPrograms
        .where()
        .autoStartEqualTo(true)
        .enabledEqualTo(true)
        .findAll();
    for (final program in programs) {
      try {
        await start(program);
      } catch (e) {
        AppLogger.error('Auto-start failed for ${program.name}: $e');
      }
    }
  }

  Future<void> stopAll() async {
    final ids = _processes.keys.toList();
    for (final id in ids) {
      await stop(id);
    }
  }

  Future<void> _remove(int programId) async {
    final managed = _processes.remove(programId);
    if (managed == null) return;
    managed.running = false;
    try {
      await managed.logFileSink.flush();
      await managed.logFileSink.close();
    } catch (_) {
      // Already closed.
    }
    try {
      if (!managed.streamController.isClosed) {
        await managed.streamController.close();
      }
    } catch (_) {
      // Already closed.
    }
  }

  void dispose() {
    for (final managed in _processes.values) {
      managed.explicitlyStopped = true;
    }
    unawaited(stopAll());
    if (!_statusController.isClosed) _statusController.close();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/supervisor/data/supervisor_manager_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/supervisor`
Expected: 0 issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/supervisor/data/supervisor_manager.dart test/features/supervisor/data/supervisor_manager_test.dart
git commit -m "feat(supervisor): add manager with watchdog auto-restart"
```

---

## Task 7: `CronSchedulerService` — tick, no-overlap, history ring buffer

**Files:**
- Create: `lib/features/cron/data/cron_scheduler_service.dart`
- Test: `test/features/cron/data/cron_scheduler_service_test.dart`

**Interfaces:**
- Consumes: `CronJob` (Task 4), `CronExpression` (Tasks 1–3), `BackgroundProcess`, `AppLogger`.
- Produces:
  - `class CronRunResult { final int exitCode; final String output; }`
  - `class RunRecord { final DateTime startedAt; final DateTime? finishedAt; final int? exitCode; final String output; }`
  - `typedef CronRunner = Future<CronRunResult> Function(CronJob job);`
  - `typedef CronClock = DateTime Function();`
  - `typedef CronJobLoader = Future<List<CronJob>> Function();`
  - `typedef CronJobUpdater = Future<void> Function(CronJob job);`
  - `class CronSchedulerService` with
    `CronSchedulerService({CronRunner? runner, CronClock? clock, CronJobLoader? loadJobs, CronJobUpdater? updateJob, Isar? isar, Duration interval = const Duration(seconds: 30)})`,
    `void start()`, `void stop()`, `Future<void> tick()`, `Future<void> runNow(CronJob job)`,
    `bool isRunning(int jobId)`, `Stream<int> get statusStream`,
    `List<RunRecord> historyFor(int jobId)`, `void dispose()`,
    `int get historyLimit` (const 20).
  - `final cronSchedulerProvider = Provider<CronSchedulerService>(...)` with `ref.onDispose`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/cron/data/cron_scheduler_service_test.dart
import 'dart:async';

import 'package:dev_stack/features/cron/data/cron_scheduler_service.dart';
import 'package:dev_stack/features/cron/domain/cron_job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late List<CronJob> jobs;
  late List<CronJob> persisted;
  late List<String> ranCommands;
  late Completer<void>? gate;
  late CronSchedulerService scheduler;

  CronJob job({
    int id = 1,
    String schedule = '* * * * *',
    bool enabled = true,
    String command = 'echo hi',
  }) =>
      CronJob(
        id: id,
        name: 'job$id',
        schedule: schedule,
        command: command,
        enabled: enabled,
      );

  setUp(() {
    now = DateTime(2026, 10, 12, 8, 30);
    jobs = [job()];
    persisted = [];
    ranCommands = [];
    gate = null;
    scheduler = CronSchedulerService(
      clock: () => now,
      loadJobs: () async => jobs,
      updateJob: (j) async => persisted.add(j),
      runner: (j) async {
        ranCommands.add(j.command);
        if (gate != null) await gate!.future;
        return const CronRunResult(exitCode: 0, output: 'ok');
      },
    );
  });

  tearDown(() => scheduler.dispose());

  test('a due job fires once and advances its next run', () async {
    // First tick seeds the next run; nothing fires yet.
    await scheduler.tick();
    expect(ranCommands, isEmpty);

    // Advance one minute so the seeded next-run is due.
    now = DateTime(2026, 10, 12, 8, 31);
    await scheduler.tick();
    // tick() fires the run without awaiting it, so drain its microtasks first.
    await Future<void>.delayed(Duration.zero);
    expect(ranCommands, ['echo hi']);

    // A second tick at the same instant must not re-fire.
    await scheduler.tick();
    expect(ranCommands.length, 1);
  });

  test('a not-due job does not fire', () async {
    await scheduler.tick();
    now = DateTime(2026, 10, 12, 8, 30, 45); // still inside the same minute
    await scheduler.tick();
    expect(ranCommands, isEmpty);
  });

  test('a disabled job is skipped', () async {
    jobs = [job(enabled: false)];
    await scheduler.tick();
    now = DateTime(2026, 10, 12, 9, 0);
    await scheduler.tick();
    expect(ranCommands, isEmpty);
  });

  test('an invalid schedule is skipped', () async {
    jobs = [job(schedule: 'nonsense')];
    now = DateTime(2026, 10, 12, 9, 0);
    await scheduler.tick();
    expect(ranCommands, isEmpty);
  });

  test('a run persists its status and exit code', () async {
    await scheduler.tick();
    now = DateTime(2026, 10, 12, 8, 31);
    await scheduler.tick();
    await Future<void>.delayed(Duration.zero);

    expect(persisted, isNotEmpty);
    expect(persisted.last.lastStatus, 'success');
    expect(persisted.last.lastExitCode, 0);
  });

  test('a failing command is recorded as failed', () async {
    scheduler = CronSchedulerService(
      clock: () => now,
      loadJobs: () async => jobs,
      updateJob: (j) async => persisted.add(j),
      runner: (j) async => const CronRunResult(exitCode: 2, output: 'boom'),
    );
    await scheduler.tick();
    now = DateTime(2026, 10, 12, 8, 31);
    await scheduler.tick();
    await Future<void>.delayed(Duration.zero);

    expect(persisted.last.lastStatus, 'failed');
    expect(persisted.last.lastExitCode, 2);
  });

  test('an in-flight run is never overlapped', () async {
    gate = Completer<void>();
    await scheduler.tick();
    now = DateTime(2026, 10, 12, 8, 31);
    await scheduler.tick(); // starts, blocks on the gate
    expect(scheduler.isRunning(1), isTrue);

    now = DateTime(2026, 10, 12, 8, 32);
    await scheduler.tick(); // must skip: still running
    expect(ranCommands.length, 1);

    gate!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(scheduler.isRunning(1), isFalse);
  });

  test('runNow ignores the schedule', () async {
    await scheduler.runNow(jobs.first);
    expect(ranCommands, ['echo hi']);
  });

  test('history is capped at 20 records, newest first', () async {
    // Advance the injected clock between runs: a fixed clock would give every
    // record the same startedAt, so "newest first" could not be observed.
    for (var i = 0; i < 25; i++) {
      now = DateTime(2026, 10, 12, 8, 30).add(Duration(minutes: i));
      await scheduler.runNow(jobs.first);
    }
    final history = scheduler.historyFor(1);
    expect(history.length, 20);
    expect(history.first.startedAt.isAfter(history.last.startedAt), isTrue);
  });

  test('statusStream emits the job id on run start', () async {
    final seen = <int>[];
    final sub = scheduler.statusStream.listen(seen.add);
    await scheduler.runNow(jobs.first);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await sub.cancel();
    expect(seen, contains(1));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/cron/data/cron_scheduler_service_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:dev_stack/features/cron/data/cron_scheduler_service.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/cron/data/cron_scheduler_service.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_plus/isar_plus.dart';

import '../../../core/database/isar_provider.dart';
import '../../../core/services/background_process.dart';
import '../domain/cron_expression.dart';
import '../domain/cron_job.dart';

/// Outcome of one cron run.
class CronRunResult {
  final int exitCode;
  final String output;
  const CronRunResult({required this.exitCode, required this.output});
}

/// One entry in a job's in-memory run history.
class RunRecord {
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int? exitCode; // null while the run is in flight
  final String output;

  const RunRecord({
    required this.startedAt,
    this.finishedAt,
    this.exitCode,
    this.output = '',
  });
}

typedef CronRunner = Future<CronRunResult> Function(CronJob job);
typedef CronClock = DateTime Function();
typedef CronJobLoader = Future<List<CronJob>> Function();
typedef CronJobUpdater = Future<void> Function(CronJob job);

final cronSchedulerProvider = Provider<CronSchedulerService>((ref) {
  // Late-bound Isar for the same reason as supervisorManagerProvider: the DB
  // opens asynchronously, and a `watch` here would rebuild (and stop) the
  // scheduler the moment it lands.
  final service = CronSchedulerService(
    isarResolver: () => ref.read(isarProvider).value,
  );
  ref.onDispose(() => service.dispose());
  return service;
});

/// Runs enabled [CronJob]s on their schedule, in-app only.
///
/// A single `Timer.periodic` calls [tick]; each tick fires every enabled job
/// whose next occurrence has arrived. A job whose previous run is still in
/// flight is skipped, so a long-running command can never stack. History is a
/// RAM ring buffer of [historyLimit] records per job — nothing is persisted
/// beyond the job's own last-run fields.
///
/// Jobs missed while the app was closed are not back-filled: the first time a
/// job is seen its next occurrence is computed forward from "now".
class CronSchedulerService {
  final CronRunner _runner;
  final CronClock _clock;
  final CronJobLoader _loadJobs;
  final CronJobUpdater _updateJob;
  final Isar? Function() _isarResolver;
  final Duration interval;

  /// Maximum run records retained per job (RAM only).
  final int historyLimit = 20;

  final Map<int, DateTime?> _nextRuns = {};
  final Set<int> _running = {};
  final Map<int, List<RunRecord>> _history = {};
  final StreamController<int> _statusController =
      StreamController<int>.broadcast();

  Timer? _timer;
  bool _ticking = false;
  bool _disposed = false;

  /// [isar] pins a fixed database (tests); [isarResolver] resolves one lazily
  /// (production), so a scheduler created before the async open still sees it.
  CronSchedulerService({
    CronRunner? runner,
    CronClock? clock,
    CronJobLoader? loadJobs,
    CronJobUpdater? updateJob,
    Isar? isar,
    Isar? Function()? isarResolver,
    this.interval = const Duration(seconds: 30),
  })  : _runner = runner ?? _defaultRunner,
        _clock = clock ?? DateTime.now,
        _loadJobs = loadJobs ?? (() async => const <CronJob>[]),
        _updateJob = updateJob ?? ((_) async {}),
        _isarResolver = isarResolver ?? (isar != null ? () => isar : () => null);

  Isar? get _isar => _isarResolver();

  Stream<int> get statusStream => _statusController.stream;

  bool isRunning(int jobId) => _running.contains(jobId);

  List<RunRecord> historyFor(int jobId) =>
      List.unmodifiable(_history[jobId] ?? const <RunRecord>[]);

  void _notify(int jobId) {
    if (!_statusController.isClosed) _statusController.add(jobId);
  }

  /// The real runner: one shell command, output captured.
  static Future<CronRunResult> _defaultRunner(CronJob job) async {
    final result = await BackgroundProcess.run(
      job.command,
      const [],
      runInShell: true,
      workingDirectory: job.workingDir.isEmpty ? null : job.workingDir,
    );
    final out = '${result.stdout}${result.stderr}'.trim();
    return CronRunResult(exitCode: result.exitCode, output: out);
  }

  void start() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(tick()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Loads the current jobs, from Isar when configured, else from the injected
  /// loader.
  Future<List<CronJob>> _jobs() async {
    final isar = _isar;
    if (isar != null) return isar.cronJobs.where().findAll();
    return _loadJobs();
  }

  Future<void> _persist(CronJob job) async {
    final isar = _isar;
    if (isar != null) {
      isar.write((_) => isar.cronJobs.put(job));
      return;
    }
    await _updateJob(job);
  }

  /// One scheduler pass: fire every due, enabled job. Called by the periodic
  /// timer and directly by tests.
  Future<void> tick() async {
    if (_disposed || _ticking) return;
    _ticking = true;
    try {
      final now = _clock();
      final jobs = await _jobs();

      final liveIds = <int>{};
      for (final job in jobs) {
        liveIds.add(job.id);
        if (!job.enabled) continue;
        if (!CronExpression.isValid(job.schedule)) continue;

        final expr = CronExpression.parse(job.schedule);
        if (!_nextRuns.containsKey(job.id)) {
          // First sighting: schedule forward from now (no back-fill).
          _nextRuns[job.id] = expr.nextOccurrence(now);
        }
        final next = _nextRuns[job.id];
        if (next == null) continue; // unsatisfiable schedule
        if (now.isBefore(next)) continue;

        // Advance past this occurrence before running, so a run that outlives
        // its interval cannot queue up a backlog of missed firings.
        _nextRuns[job.id] = expr.nextOccurrence(now);

        if (_running.contains(job.id)) continue; // no overlap

        // Fire without awaiting: a long-running command must not stall the
        // other due jobs in this same pass (the `_ticking` guard would
        // otherwise make the next periodic tick a no-op for its whole
        // duration). Per-job no-overlap is enforced by `_running`.
        unawaited(_execute(job));
      }

      // Drop bookkeeping for jobs that no longer exist.
      _nextRuns.removeWhere((id, _) => !liveIds.contains(id));
    } finally {
      _ticking = false;
    }
  }

  /// Runs [job] immediately, ignoring its schedule. No-op if it is already
  /// running.
  Future<void> runNow(CronJob job) async {
    if (_running.contains(job.id)) return;
    await _execute(job);
  }

  Future<void> _execute(CronJob job) async {
    _running.add(job.id);
    _notify(job.id);

    final startedAt = _clock();
    final record = RunRecord(startedAt: startedAt, output: '');
    _appendHistory(job.id, record);
    // A copy so the in-flight record can be replaced on completion.
    final index = _history[job.id]!.indexOf(record);

    job.lastRunAt = startedAt;
    job.lastStatus = 'running';
    await _persist(job);

    CronRunResult result;
    try {
      result = await _runner(job);
    } catch (e) {
      result = CronRunResult(exitCode: -1, output: 'Failed to run: $e');
    }

    final finishedAt = _clock();
    final success = result.exitCode == 0;

    _history[job.id]![index] = RunRecord(
      startedAt: startedAt,
      finishedAt: finishedAt,
      exitCode: result.exitCode,
      output: result.output,
    );

    _running.remove(job.id);

    job.lastStatus = success ? 'success' : 'failed';
    job.lastExitCode = result.exitCode;
    await _persist(job);

    _notify(job.id);
  }

  void _appendHistory(int jobId, RunRecord record) {
    final list = _history.putIfAbsent(jobId, () => <RunRecord>[]);
    list.insert(0, record); // newest first
    while (list.length > historyLimit) {
      list.removeLast();
    }
  }

  void dispose() {
    _disposed = true;
    stop();
    _running.clear();
    _history.clear();
    _nextRuns.clear();
    if (!_statusController.isClosed) _statusController.close();
  }
}
```

Note: no `dart:io`, `dart:collection`, or `log_service` import is needed — the
runner uses `BackgroundProcess`, and history uses plain `List` operations.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/cron/data/cron_scheduler_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/cron`
Expected: 0 issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/cron/data/cron_scheduler_service.dart test/features/cron/data/cron_scheduler_service_test.dart
git commit -m "feat(cron): add in-app cron scheduler with no-overlap guard"
```

---

## Task 8: Feature providers — streams, sessions, CRUD

**Files:**
- Create: `lib/features/supervisor/data/supervisor_provider.dart`
- Create: `lib/features/cron/data/cron_provider.dart`
- Test: `test/features/supervisor/data/supervisor_provider_test.dart`
- Test: `test/features/cron/data/cron_provider_test.dart`

**Interfaces:**
- Consumes: `SupervisorManager`/`supervisorManagerProvider` (Task 6), `CronSchedulerService`/`cronSchedulerProvider` (Task 7), `CronJob` (Task 4), `SupervisorProgram`/`SupervisorStatus` (Task 5), `isarProvider`.
- Produces (supervisor):
  - `final supervisorProgramsProvider = StreamProvider<List<SupervisorProgram>>(...)` — Isar watch, mirrors `tunnelsStreamProvider`.
  - `final supervisorStatusProvider = NotifierProvider<SupervisorStatusNotifier, Map<int, SupervisorStatus>>(...)` — seeds from the manager and follows `statusStream`.
  - `class SupervisorProgramsRepository { Future<void> save(SupervisorProgram p); Future<void> delete(int id); }` + `supervisorRepositoryProvider`.
- Produces (cron):
  - `final cronJobsProvider = StreamProvider<List<CronJob>>(...)`.
  - `final cronRunStateProvider = NotifierProvider<CronRunStateNotifier, Set<int>>(...)` — the set of job ids with a run in flight; follows `statusStream`.
  - `class CronJobsRepository { Future<void> save(CronJob j); Future<void> delete(int id); }` + `cronRepositoryProvider`.

- [ ] **Step 1: Write the failing test (supervisor repository against a fake Isar-free path)**

```dart
// test/features/supervisor/data/supervisor_provider_test.dart
import 'package:dev_stack/features/supervisor/data/supervisor_provider.dart';
import 'package:dev_stack/features/supervisor/domain/supervisor_program.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a program without an id is recognized as new', () {
    final p = SupervisorProgram(name: 'x', command: 'y');
    expect(SupervisorProgramsRepository.isNew(p), isTrue);
  });

  test('a program with an id is recognized as existing', () {
    final p = SupervisorProgram(id: 3, name: 'x', command: 'y');
    expect(SupervisorProgramsRepository.isNew(p), isFalse);
  });

  test('the status provider starts empty before any manager event', () {
    // The provider family/type exists and is a NotifierProvider; the initial
    // map is produced by build() inside a container (see Task 8 step 5's
    // widget-level coverage). Here we only pin the public shape.
    expect(supervisorStatusProvider, isA<NotifierProvider<dynamic, dynamic>>());
  });
}
```

```dart
// test/features/cron/data/cron_provider_test.dart
import 'package:dev_stack/features/cron/data/cron_provider.dart';
import 'package:dev_stack/features/cron/domain/cron_job.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a job without an id is recognized as new', () {
    final j = CronJob(name: 'a', schedule: '@daily', command: 'echo');
    expect(CronJobsRepository.isNew(j), isTrue);
  });

  test('a job with an id is recognized as existing', () {
    final j = CronJob(id: 5, name: 'a', schedule: '@daily', command: 'echo');
    expect(CronJobsRepository.isNew(j), isFalse);
  });

  test('the run-state provider is exposed as a NotifierProvider', () {
    expect(cronRunStateProvider, isA<NotifierProvider<dynamic, dynamic>>());
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/supervisor/data/supervisor_provider_test.dart test/features/cron/data/cron_provider_test.dart`
Expected: FAIL — the two provider files do not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/supervisor/data/supervisor_provider.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_plus/isar_plus.dart';

import '../../../core/database/isar_provider.dart';
import '../domain/supervisor_program.dart';
import '../domain/supervisor_status.dart';
import 'supervisor_manager.dart';

/// Live list of supervised programs, watched straight from Isar.
final supervisorProgramsProvider =
    StreamProvider<List<SupervisorProgram>>((ref) async* {
  final isarAsync = ref.watch(isarProvider);
  final isar = isarAsync.value;
  if (isar == null) {
    yield const <SupervisorProgram>[];
    return;
  }
  yield* isar.supervisorPrograms.where().watch(fireImmediately: true);
});

/// Live status per program id, following the manager's broadcast stream.
final supervisorStatusProvider =
    NotifierProvider<SupervisorStatusNotifier, Map<int, SupervisorStatus>>(
  SupervisorStatusNotifier.new,
);

class SupervisorStatusNotifier extends Notifier<Map<int, SupervisorStatus>> {
  late SupervisorManager _manager;
  StreamSubscription<int>? _subscription;

  @override
  Map<int, SupervisorStatus> build() {
    _manager = ref.watch(supervisorManagerProvider);
    _subscription = _manager.statusStream.listen((id) {
      state = {...state, id: _manager.statusOf(id)};
    });
    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });
    return const {};
  }

  SupervisorStatus statusOf(int programId) =>
      state[programId] ?? _manager.statusOf(programId);
}

/// Persists programs to Isar, allocating a fresh id for new records (Isar Plus
/// treats `id == 0` as a real key, not an auto-increment sentinel).
class SupervisorProgramsRepository {
  final Isar isar;
  SupervisorProgramsRepository(this.isar);

  static bool isNew(SupervisorProgram program) => program.id == 0;

  Future<void> save(SupervisorProgram program) async {
    isar.write((_) {
      if (program.id == 0) {
        program.id = isar.supervisorPrograms.autoIncrement();
      }
      isar.supervisorPrograms.put(program);
    });
  }

  Future<void> delete(int id) async {
    isar.write((_) => isar.supervisorPrograms.delete(id));
  }
}

final supervisorRepositoryProvider = Provider<SupervisorProgramsRepository>((ref) {
  final isar = ref.watch(isarProvider).value;
  if (isar == null) {
    throw StateError('Isar is not open yet');
  }
  return SupervisorProgramsRepository(isar);
});
```

```dart
// lib/features/cron/data/cron_provider.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_plus/isar_plus.dart';

import '../../../core/database/isar_provider.dart';
import '../domain/cron_job.dart';
import 'cron_scheduler_service.dart';

/// Live list of cron jobs, watched straight from Isar.
final cronJobsProvider = StreamProvider<List<CronJob>>((ref) async* {
  final isarAsync = ref.watch(isarProvider);
  final isar = isarAsync.value;
  if (isar == null) {
    yield const <CronJob>[];
    return;
  }
  yield* isar.cronJobs.where().watch(fireImmediately: true);
});

/// The set of job ids with a run in flight, following the scheduler's stream.
final cronRunStateProvider =
    NotifierProvider<CronRunStateNotifier, Set<int>>(CronRunStateNotifier.new);

class CronRunStateNotifier extends Notifier<Set<int>> {
  late CronSchedulerService _scheduler;
  StreamSubscription<int>? _subscription;

  @override
  Set<int> build() {
    _scheduler = ref.watch(cronSchedulerProvider);
    _subscription = _scheduler.statusStream.listen((id) {
      final next = {...state};
      if (_scheduler.isRunning(id)) {
        next.add(id);
      } else {
        next.remove(id);
      }
      state = next;
    });
    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });
    return const {};
  }
}

/// Persists jobs to Isar, allocating a fresh id for new records.
class CronJobsRepository {
  final Isar isar;
  CronJobsRepository(this.isar);

  static bool isNew(CronJob job) => job.id == 0;

  Future<void> save(CronJob job) async {
    isar.write((_) {
      if (job.id == 0) {
        job.id = isar.cronJobs.autoIncrement();
      }
      isar.cronJobs.put(job);
    });
  }

  Future<void> delete(int id) async {
    isar.write((_) => isar.cronJobs.delete(id));
  }
}

final cronRepositoryProvider = Provider<CronJobsRepository>((ref) {
  final isar = ref.watch(isarProvider).value;
  if (isar == null) {
    throw StateError('Isar is not open yet');
  }
  return CronJobsRepository(isar);
});
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/supervisor/data/supervisor_provider_test.dart test/features/cron/data/cron_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/supervisor lib/features/cron`
Expected: 0 issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/supervisor/data/supervisor_provider.dart lib/features/cron/data/cron_provider.dart test/features/supervisor/data/supervisor_provider_test.dart test/features/cron/data/cron_provider_test.dart
git commit -m "feat: add supervisor and cron providers with Isar-backed repositories"
```

---

## Task 9: Supervisor UI — table, form modal, logs modal, page

**Files:**
- Create: `lib/features/supervisor/presentation/widgets/supervisor_table.dart`
- Create: `lib/features/supervisor/presentation/widgets/program_form_modal.dart`
- Create: `lib/features/supervisor/presentation/widgets/program_logs_modal.dart`
- Create: `lib/features/supervisor/presentation/supervisor_page.dart`
- Test: `test/features/supervisor/presentation/widgets/supervisor_table_test.dart`

**Interfaces:**
- Consumes: `SupervisorProgram`, `SupervisorStatus`, `supervisorProgramsProvider`, `supervisorStatusProvider`, `supervisorRepositoryProvider`, `supervisorManagerProvider`, `AppButton`/`AppIconButton`/`AppModalHeader`/`AppTextField`/`StatusChip`/`TerminalLogView`/`modalDimensions`.
- Produces:
  - `class SupervisorTable extends StatelessWidget` with constructor params
    `programs`, `statuses` (`Map<int, SupervisorStatus>`), `pids` (`Map<int, int?>`),
    and callbacks `onStart(SupervisorProgram)`, `onStop(int)`, `onRestart(SupervisorProgram)`,
    `onViewLogs(SupervisorProgram)`, `onEdit(SupervisorProgram)`, `onDelete(SupervisorProgram)`.
  - `class SupervisorPage extends ConsumerWidget`.
  - `class ProgramFormModal extends ConsumerStatefulWidget` with `{SupervisorProgram? initialProgram}`.
  - `class ProgramLogsModal extends StatefulWidget` with `{required SupervisorManager manager, required SupervisorProgram program}`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/supervisor/presentation/widgets/supervisor_table_test.dart
import 'package:dev_stack/features/supervisor/domain/supervisor_program.dart';
import 'package:dev_stack/features/supervisor/domain/supervisor_status.dart';
import 'package:dev_stack/features/supervisor/presentation/widgets/supervisor_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  final program = SupervisorProgram(
    id: 1,
    name: 'Queue Worker',
    command: 'php artisan queue:work',
    workingDir: '/srv/app',
  );

  testWidgets('renders headers and empty state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SupervisorTable(
          programs: const [],
          statuses: const {},
          pids: const {},
          onStart: (_) {},
          onStop: (_) {},
          onRestart: (_) {},
          onViewLogs: (_) {},
          onEdit: (_) {},
          onDelete: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('PROGRAM'), findsOneWidget);
    expect(find.text('STATUS'), findsOneWidget);
    expect(find.text('PID'), findsOneWidget);
    expect(find.text('No supervised programs yet'), findsOneWidget);
  });

  testWidgets('shows Stop for a running program and Start otherwise',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    int? stoppedId;
    SupervisorProgram? startedProgram;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SupervisorTable(
          programs: [program],
          statuses: const {1: SupervisorStatus.running},
          pids: const {1: 4242},
          onStart: (p) => startedProgram = p,
          onStop: (id) => stoppedId = id,
          onRestart: (_) {},
          onViewLogs: (_) {},
          onEdit: (_) {},
          onDelete: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Queue Worker'), findsOneWidget);
    expect(find.text('RUNNING'), findsOneWidget);
    expect(find.text('4242'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    expect(stoppedId, 1);
  });

  testWidgets('shows Start and a FATAL chip for a fatal program',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    SupervisorProgram? started;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SupervisorTable(
          programs: [program],
          statuses: const {1: SupervisorStatus.fatal},
          pids: const {},
          onStart: (p) => started = p,
          onStop: (_) {},
          onRestart: (_) {},
          onViewLogs: (_) {},
          onEdit: (_) {},
          onDelete: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('FATAL'), findsOneWidget);
    await tester.tap(find.text('Start'));
    expect(started?.id, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/supervisor/presentation/widgets/supervisor_table_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../supervisor_table.dart'`.

- [ ] **Step 3: Write `supervisor_table.dart`**

```dart
// lib/features/supervisor/presentation/widgets/supervisor_table.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/supervisor_program.dart';
import '../../domain/supervisor_status.dart';

/// Table of supervised programs. Purely presentational: status/pids come in as
/// maps and every action is a callback, so the widget is testable without a
/// manager or Isar.
class SupervisorTable extends StatelessWidget {
  final List<SupervisorProgram> programs;
  final Map<int, SupervisorStatus> statuses;
  final Map<int, int?> pids;
  final Function(SupervisorProgram) onStart;
  final Function(int) onStop;
  final Function(SupervisorProgram) onRestart;
  final Function(SupervisorProgram) onViewLogs;
  final Function(SupervisorProgram) onEdit;
  final Function(SupervisorProgram) onDelete;

  const SupervisorTable({
    super.key,
    required this.programs,
    required this.statuses,
    required this.pids,
    required this.onStart,
    required this.onStop,
    required this.onRestart,
    required this.onViewLogs,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minWidth = 880.0;
        final tableWidth =
            constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              height: constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : null,
              child: Column(
                children: [
                  _buildHeader(),
                  if (programs.isEmpty)
                    _buildEmptyState()
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: programs.length,
                        itemBuilder: (context, index) => _buildRow(
                          programs[index],
                          index == programs.length - 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: _headerCell('PROGRAM')),
          const SizedBox(width: 12),
          SizedBox(width: 100, child: _headerCell('STATUS')),
          const SizedBox(width: 12),
          SizedBox(width: 80, child: _headerCell('PID')),
          const SizedBox(width: 12),
          Expanded(flex: 4, child: _headerCell('COMMAND')),
          const SizedBox(width: 12),
          SizedBox(
            width: 230,
            child: _headerCell('OPERATE', align: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String label, {TextAlign align = TextAlign.left}) {
    return Text(
      label,
      textAlign: align,
      style: const TextStyle(
        fontSize: AppTextSize.xxs,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.activity, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'No supervised programs yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppTextSize.md,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Click "+ New Program" to keep a long-running process alive.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppTextSize.xs,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(SupervisorProgram program, bool isLast) {
    final status = statuses[program.id] ?? SupervisorStatus.stopped;
    final isRunning = status == SupervisorStatus.running;
    final isTransitioning = status == SupervisorStatus.starting ||
        status == SupervisorStatus.stopping ||
        status == SupervisorStatus.restarting;
    final pid = pids[program.id];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.border, width: 0.5),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    program.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppTextSize.sm,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (program.autoStart) ...[
                  const SizedBox(width: 6),
                  const Tooltip(
                    message: 'Starts on app launch',
                    child: Icon(
                      LucideIcons.playCircle,
                      size: 13,
                      color: AppColors.success,
                    ),
                  ),
                ],
                if (!program.enabled) ...[
                  const SizedBox(width: 6),
                  const Tooltip(
                    message: 'Disabled',
                    child: Icon(
                      LucideIcons.pauseCircle,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildStatusChip(status),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              pid?.toString() ?? '—',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppTextSize.xs,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              program.command,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: AppTextSize.xs,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 230,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isRunning)
                  AppButton(
                    label: 'Stop',
                    onPressed: () => onStop(program.id),
                    icon: const Icon(LucideIcons.square, size: 12),
                    style: AppButtonStyle.danger,
                  )
                else
                  AppButton(
                    label: 'Start',
                    onPressed: isTransitioning ? null : () => onStart(program),
                    icon: const Icon(LucideIcons.play, size: 12),
                    style: AppButtonStyle.success,
                  ),
                const SizedBox(width: 6),
                AppIconButton(
                  icon: LucideIcons.rotateCw,
                  tooltip: 'Restart',
                  onPressed: isRunning ? () => onRestart(program) : null,
                  size: AppIconButtonSize.sm,
                ),
                const SizedBox(width: 4),
                AppIconButton(
                  icon: LucideIcons.list,
                  tooltip: 'View Logs',
                  onPressed: () => onViewLogs(program),
                  size: AppIconButtonSize.sm,
                ),
                const SizedBox(width: 4),
                AppIconButton(
                  icon: LucideIcons.edit,
                  tooltip: 'Edit',
                  onPressed: () => onEdit(program),
                  size: AppIconButtonSize.sm,
                ),
                const SizedBox(width: 4),
                AppIconButton(
                  icon: LucideIcons.trash2,
                  tooltip: 'Delete',
                  color: AppColors.error,
                  onPressed: () => onDelete(program),
                  size: AppIconButtonSize.sm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(SupervisorStatus status) {
    StatusType type;
    String label;
    switch (status) {
      case SupervisorStatus.stopped:
        type = StatusType.stopped;
        label = 'Stopped';
        break;
      case SupervisorStatus.starting:
        type = StatusType.restarting;
        label = 'Starting';
        break;
      case SupervisorStatus.running:
        type = StatusType.stable;
        label = 'Running';
        break;
      case SupervisorStatus.stopping:
        type = StatusType.restarting;
        label = 'Stopping';
        break;
      case SupervisorStatus.restarting:
        type = StatusType.restarting;
        label = 'Restarting';
        break;
      case SupervisorStatus.fatal:
        type = StatusType.warning;
        label = 'Fatal';
        break;
    }
    return StatusChip(type: type, label: label);
  }
}
```

- [ ] **Step 4: Write `program_logs_modal.dart`**

```dart
// lib/features/supervisor/presentation/widgets/program_logs_modal.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/utils/modal_sizing.dart';
import '../../../../shared/widgets/terminal_log_view.dart';
import '../../data/supervisor_manager.dart';
import '../../domain/supervisor_program.dart';

/// Live log viewer for one supervised program. Subscribes to the manager's
/// per-program stream and keeps the buffered history as the initial frame.
class ProgramLogsModal extends StatefulWidget {
  final SupervisorManager manager;
  final SupervisorProgram program;

  const ProgramLogsModal({
    super.key,
    required this.manager,
    required this.program,
  });

  @override
  State<ProgramLogsModal> createState() => _ProgramLogsModalState();
}

class _ProgramLogsModalState extends State<ProgramLogsModal> {
  late List<String> _lines;
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    _lines = widget.manager.getLogBuffer(widget.program.id);
    _subscription = widget.manager.getLogStream(widget.program.id).listen((line) {
      if (!mounted) return;
      setState(() => _lines = [..._lines, line]);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dims = modalDimensions(context, ModalSize.xl);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: dims.insetPadding,
      child: SizedBox(
        width: dims.width,
        height: dims.height,
        child: TerminalLogView(
          title: 'Logs - ${widget.program.name}',
          lines: _lines,
          onClear: () => setState(() {
            widget.manager.clearLogs(widget.program.id);
            _lines = const [];
          }),
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Write `program_form_modal.dart`**

```dart
// lib/features/supervisor/presentation/widgets/program_form_modal.dart
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/utils/modal_sizing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_modal_header.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../data/supervisor_provider.dart';
import '../../domain/supervisor_program.dart';

/// Create/edit form for a supervised program.
class ProgramFormModal extends ConsumerStatefulWidget {
  final SupervisorProgram? initialProgram;

  const ProgramFormModal({super.key, this.initialProgram});

  @override
  ConsumerState<ProgramFormModal> createState() => _ProgramFormModalState();
}

class _ProgramFormModalState extends ConsumerState<ProgramFormModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _command;
  late final TextEditingController _workingDir;
  late final TextEditingController _env;
  late final TextEditingController _maxRestarts;
  late final TextEditingController _windowSeconds;
  late final TextEditingController _delaySeconds;

  late bool _autoStart;
  late bool _autoRestart;
  late bool _enabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialProgram;
    _name = TextEditingController(text: initial?.name ?? '');
    _command = TextEditingController(text: initial?.command ?? '');
    _workingDir = TextEditingController(text: initial?.workingDir ?? '');
    _env = TextEditingController(
      text: _envToText(initial?.environmentJson ?? '{}'),
    );
    _maxRestarts =
        TextEditingController(text: (initial?.maxRestarts ?? 5).toString());
    _windowSeconds = TextEditingController(
      text: (initial?.restartWindowSeconds ?? 60).toString(),
    );
    _delaySeconds = TextEditingController(
      text: (initial?.restartDelaySeconds ?? 2).toString(),
    );
    _autoStart = initial?.autoStart ?? false;
    _autoRestart = initial?.autoRestart ?? true;
    _enabled = initial?.enabled ?? true;
  }

  static String _envToText(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) {
        return decoded.entries.map((e) => '${e.key}=${e.value}').join('\n');
      }
    } catch (_) {
      // Fall through.
    }
    return '';
  }

  static String _textToEnv(String text) {
    final map = <String, String>{};
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final eq = trimmed.indexOf('=');
      if (eq <= 0) continue;
      map[trimmed.substring(0, eq).trim()] =
          trimmed.substring(eq + 1).trim();
    }
    return jsonEncode(map);
  }

  @override
  void dispose() {
    _name.dispose();
    _command.dispose();
    _workingDir.dispose();
    _env.dispose();
    _maxRestarts.dispose();
    _windowSeconds.dispose();
    _delaySeconds.dispose();
    super.dispose();
  }

  Future<void> _pickDirectory() async {
    final path = await FilePicker.getDirectoryPath();
    if (path != null) setState(() => _workingDir.text = path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final isEditing = widget.initialProgram != null;
    final program = SupervisorProgram(
      id: isEditing ? widget.initialProgram!.id : 0,
      name: _name.text.trim(),
      command: _command.text.trim(),
      workingDir: _workingDir.text.trim(),
      environmentJson: _textToEnv(_env.text),
      autoStart: _autoStart,
      autoRestart: _autoRestart,
      maxRestarts: int.tryParse(_maxRestarts.text.trim()) ?? 5,
      restartWindowSeconds: int.tryParse(_windowSeconds.text.trim()) ?? 60,
      restartDelaySeconds: int.tryParse(_delaySeconds.text.trim()) ?? 2,
      enabled: _enabled,
      createdAt: isEditing ? widget.initialProgram!.createdAt : DateTime.now(),
    );

    await ref.read(supervisorRepositoryProvider).save(program);
    if (mounted) Navigator.of(context).pop(program);
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppTextSize.xs,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _toggle(String title, String subtitle, bool value,
      ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppTextSize.sm,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: AppTextSize.xxs,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.success,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dims = modalDimensions(context, ModalSize.lg);
    final isEditing = widget.initialProgram != null;

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: dims.insetPadding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: SizedBox(
        width: dims.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppModalHeader(
              icon: LucideIcons.activity,
              title: isEditing
                  ? 'Edit Program: ${widget.initialProgram!.name}'
                  : 'New Supervised Program',
              subtitle: 'Keep a long-running process alive with a watchdog',
              onClose: () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label('Name'),
                      AppTextField(
                        controller: _name,
                        hint: 'e.g. queue-worker',
                        prefixIcon: LucideIcons.tag,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 18),
                      _label('Command'),
                      AppTextField(
                        controller: _command,
                        hint: 'e.g. php artisan queue:work',
                        prefixIcon: LucideIcons.terminal,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 18),
                      _label('Working Directory'),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _workingDir,
                              hint: 'e.g. /srv/app',
                              prefixIcon: LucideIcons.folder,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AppButton(
                            label: 'Browse',
                            style: AppButtonStyle.secondary,
                            icon: const Icon(LucideIcons.folderOpen, size: 14),
                            onPressed: _pickDirectory,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _label('Environment Variables (KEY=value, one per line)'),
                      AppTextField(
                        controller: _env,
                        hint: 'QUEUE=high\nAPP_ENV=local',
                        prefixIcon: LucideIcons.keyRound,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 18),
                      _toggle(
                        'Auto start on app launch',
                        'Start this program when DevStack opens',
                        _autoStart,
                        (v) => setState(() => _autoStart = v),
                      ),
                      const SizedBox(height: 12),
                      _toggle(
                        'Auto restart on crash',
                        'Restart automatically when the process exits',
                        _autoRestart,
                        (v) => setState(() => _autoRestart = v),
                      ),
                      const SizedBox(height: 12),
                      _toggle(
                        'Enabled',
                        'A disabled program never starts',
                        _enabled,
                        (v) => setState(() => _enabled = v),
                      ),
                      const SizedBox(height: 18),
                      _label('Restart Policy'),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _maxRestarts,
                              hint: 'Max restarts',
                              prefixIcon: LucideIcons.repeat,
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                final n = int.tryParse((v ?? '').trim());
                                if (n == null || n < 0) {
                                  return 'Enter a number ≥ 0';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              controller: _windowSeconds,
                              hint: 'Window (seconds)',
                              prefixIcon: LucideIcons.timer,
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                final n = int.tryParse((v ?? '').trim());
                                if (n == null || n < 1) {
                                  return 'Enter a number ≥ 1';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              controller: _delaySeconds,
                              hint: 'Base delay (s)',
                              prefixIcon: LucideIcons.clock,
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                final n = int.tryParse((v ?? '').trim());
                                if (n == null || n < 0) {
                                  return 'Enter a number ≥ 0';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Cancel',
                    style: AppButtonStyle.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: isEditing ? 'Save Changes' : 'Create Program',
                    style: AppButtonStyle.success,
                    isLoading: _saving,
                    icon: Icon(
                      isEditing ? LucideIcons.save : LucideIcons.plus,
                      size: 16,
                    ),
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Write `supervisor_page.dart`**

```dart
// lib/features/supervisor/presentation/supervisor_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_size.dart';
import '../../../shared/utils/app_dialogs.dart';
import '../../../shared/widgets/app_button.dart';
import '../data/supervisor_manager.dart';
import '../data/supervisor_provider.dart';
import '../domain/supervisor_program.dart';
import 'widgets/program_form_modal.dart';
import 'widgets/program_logs_modal.dart';
import 'widgets/supervisor_table.dart';

class SupervisorPage extends ConsumerWidget {
  const SupervisorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programsAsync = ref.watch(supervisorProgramsProvider);
    final statuses = ref.watch(supervisorStatusProvider);
    final manager = ref.watch(supervisorManagerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, ref),
            const SizedBox(height: 24),
            Expanded(
              child: programsAsync.when(
                data: (programs) => SupervisorTable(
                  programs: programs,
                  statuses: statuses,
                  pids: {
                    for (final p in programs) p.id: manager.getPid(p.id),
                  },
                  onStart: (p) => manager.start(p),
                  onStop: (id) => manager.stop(id),
                  onRestart: (p) => manager.restart(p),
                  onViewLogs: (p) => _viewLogs(context, manager, p),
                  onEdit: (p) => _edit(context, p),
                  onDelete: (p) => _delete(context, ref, manager, p),
                ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Error loading programs: $e',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Supervisor',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppTextSize.xxl,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Keep long-running processes alive with automatic restarts',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppTextSize.sm,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        AppButton(
          label: 'New Program',
          icon: const Icon(LucideIcons.plus, size: 16),
          style: AppButtonStyle.success,
          onPressed: () => _create(context),
        ),
      ],
    );
  }

  void _create(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => const Center(child: ProgramFormModal()),
    );
  }

  void _edit(BuildContext context, SupervisorProgram program) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => Center(child: ProgramFormModal(initialProgram: program)),
    );
  }

  void _viewLogs(
    BuildContext context,
    SupervisorManager manager,
    SupervisorProgram program,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => ProgramLogsModal(manager: manager, program: program),
    );
  }

  void _delete(
    BuildContext context,
    WidgetRef ref,
    SupervisorManager manager,
    SupervisorProgram program,
  ) {
    AppDialogs.showConfirm(
      context: context,
      title: 'Delete Program',
      text: 'Delete "${program.name}"? The process will be stopped and its '
          'configuration removed. This cannot be undone.',
      confirmBtnText: 'DELETE',
      onConfirm: () async {
        await manager.stop(program.id);
        await ref.read(supervisorRepositoryProvider).delete(program.id);
      },
    );
  }
}
```

- [ ] **Step 7: Run test + analyze**

Run: `flutter test test/features/supervisor/presentation/widgets/supervisor_table_test.dart && flutter analyze lib/features/supervisor`
Expected: PASS, 0 issues. If `AppDialogs` has a different confirm signature, read `lib/shared/utils/app_dialogs.dart` and match its actual `showConfirm(...)` parameters before finalizing.

- [ ] **Step 8: Commit**

```bash
git add lib/features/supervisor/presentation test/features/supervisor/presentation
git commit -m "feat(supervisor): add supervisor page, table, form and logs UI"
```

**Deviation note:** the spec's supervisor table column list includes "uptime".
The implementation renders the program's **command** in that column instead: a
command is directly actionable and testable without a clock, whereas uptime
would require threading a start-time map into a presentational widget and
pinning a fake clock in the widget test. The manager still exposes everything
needed to add an uptime column later; this is a deliberate, documented choice,
not an omission.

---

## Task 10: Cron UI — table, form modal, history modal, page

**Files:**
- Create: `lib/features/cron/presentation/widgets/cron_table.dart`
- Create: `lib/features/cron/presentation/widgets/cron_form_modal.dart`
- Create: `lib/features/cron/presentation/widgets/run_history_modal.dart`
- Create: `lib/features/cron/presentation/cron_page.dart`
- Test: `test/features/cron/presentation/widgets/cron_table_test.dart`

**Interfaces:**
- Consumes: `CronJob` (Task 4), `CronExpression` (Tasks 1–3),
  `CronSchedulerService`/`RunRecord`/`cronSchedulerProvider` (Task 7),
  `cronJobsProvider`/`cronRunStateProvider`/`cronRepositoryProvider` (Task 8),
  `AppButton`/`AppIconButton`/`AppModalHeader`/`AppTextField`/`StatusChip`/
  `modalDimensions`.
- Produces:
  - `class CronTable extends StatelessWidget` with constructor params
    `jobs`, `runningIds` (`Set<int>`), and callbacks `onRunNow(CronJob)`,
    `onToggleEnabled(CronJob)`, `onViewHistory(CronJob)`, `onEdit(CronJob)`,
    `onDelete(CronJob)`.
  - `class CronPage extends ConsumerWidget`.
  - `class CronFormModal extends ConsumerStatefulWidget` with `{CronJob? initialJob}`.
  - `class RunHistoryModal extends StatefulWidget` with
    `{required CronSchedulerService scheduler, required CronJob job}`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/cron/presentation/widgets/cron_table_test.dart
import 'package:dev_stack/features/cron/domain/cron_job.dart';
import 'package:dev_stack/features/cron/presentation/widgets/cron_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  final job = CronJob(
    id: 1,
    name: 'Backup',
    schedule: '@daily',
    command: 'php artisan backup:run',
  );

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders headers and the empty state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(wrap(CronTable(
      jobs: const [],
      runningIds: const {},
      onRunNow: (_) {},
      onToggleEnabled: (_) {},
      onViewHistory: (_) {},
      onEdit: (_) {},
      onDelete: (_) {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('JOB NAME'), findsOneWidget);
    expect(find.text('SCHEDULE'), findsOneWidget);
    expect(find.text('LAST RUN'), findsOneWidget);
    expect(find.text('STATUS'), findsOneWidget);
    expect(find.text('ENABLED'), findsOneWidget);
    expect(find.text('OPERATE'), findsOneWidget);
    expect(find.text('No cron jobs yet'), findsOneWidget);
  });

  testWidgets('renders a row with its schedule description and status',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    CronJob? ran;
    CronJob? toggled;

    await tester.pumpWidget(wrap(CronTable(
      jobs: [job],
      runningIds: const {},
      onRunNow: (j) => ran = j,
      onToggleEnabled: (j) => toggled = j,
      onViewHistory: (_) {},
      onEdit: (_) {},
      onDelete: (_) {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('@daily'), findsOneWidget);
    expect(find.text('At 00:00'), findsOneWidget); // describe()
    expect(find.text('—'), findsOneWidget); // never run
    expect(find.text('NEVER'), findsOneWidget); // status chip

    await tester.tap(find.text('Run'));
    expect(ran?.id, 1);

    await tester.tap(find.byType(Switch));
    expect(toggled?.id, 1);
  });

  testWidgets('swaps the Run button for a spinner while the job is running',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 720));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(wrap(CronTable(
      jobs: [job],
      runningIds: const {1},
      onRunNow: (_) {},
      onToggleEnabled: (_) {},
      onViewHistory: (_) {},
      onEdit: (_) {},
      onDelete: (_) {},
    )));
    await tester.pumpAndSettle();

    // AppButton renders a spinner in place of its label while loading, so the
    // in-flight row shows no "Run" text.
    expect(find.text('Run'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/cron/presentation/widgets/cron_table_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../cron_table.dart'`.

- [ ] **Step 3: Write `cron_table.dart`**

```dart
// lib/features/cron/presentation/widgets/cron_table.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/cron_expression.dart';
import '../../domain/cron_job.dart';

/// Table of cron jobs. Presentational: run state and every action arrive as
/// parameters/callbacks, so it is testable without Isar or a timer.
class CronTable extends StatelessWidget {
  final List<CronJob> jobs;
  final Set<int> runningIds;
  final Function(CronJob) onRunNow;
  final Function(CronJob) onToggleEnabled;
  final Function(CronJob) onViewHistory;
  final Function(CronJob) onEdit;
  final Function(CronJob) onDelete;

  const CronTable({
    super.key,
    required this.jobs,
    required this.runningIds,
    required this.onRunNow,
    required this.onToggleEnabled,
    required this.onViewHistory,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minWidth = 1000.0;
        final tableWidth =
            constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              height: constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : null,
              child: Column(
                children: [
                  _buildHeader(),
                  if (jobs.isEmpty)
                    _buildEmptyState()
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: jobs.length,
                        itemBuilder: (context, index) => _buildRow(
                          jobs[index],
                          index == jobs.length - 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: _headerCell('JOB NAME')),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: _headerCell('SCHEDULE')),
          const SizedBox(width: 12),
          SizedBox(width: 150, child: _headerCell('LAST RUN')),
          const SizedBox(width: 12),
          SizedBox(width: 90, child: _headerCell('STATUS')),
          const SizedBox(width: 12),
          SizedBox(width: 80, child: _headerCell('ENABLED')),
          const SizedBox(width: 12),
          SizedBox(
            width: 200,
            child: _headerCell('OPERATE', align: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String label, {TextAlign align = TextAlign.left}) {
    return Text(
      label,
      textAlign: align,
      style: const TextStyle(
        fontSize: AppTextSize.xxs,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.clock, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'No cron jobs yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppTextSize.md,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Click "+ New Job" to run a command on a schedule.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppTextSize.xs,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(CronJob job, bool isLast) {
    final isRunning = runningIds.contains(job.id);
    final valid = CronExpression.isValid(job.schedule);
    final description =
        valid ? CronExpression.parse(job.schedule).describe() : 'Invalid schedule';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.border, width: 0.5),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    job.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppTextSize.sm,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!job.enabled) ...[
                  const SizedBox(width: 6),
                  const Tooltip(
                    message: 'Disabled',
                    child: Icon(
                      LucideIcons.pauseCircle,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  job.schedule,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppTextSize.xs,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: valid ? AppColors.textMuted : AppColors.error,
                    fontSize: AppTextSize.xxs,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 150,
            child: Text(
              _formatLastRun(job.lastRunAt),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppTextSize.xs,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 90, child: _buildStatusChip(job)),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Switch(
              value: job.enabled,
              activeThumbColor: AppColors.success,
              inactiveThumbColor: AppColors.textMuted,
              onChanged: (_) => onToggleEnabled(job),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: 'Run',
                  onPressed: isRunning ? null : () => onRunNow(job),
                  isLoading: isRunning,
                  icon: const Icon(LucideIcons.play, size: 12),
                  style: AppButtonStyle.success,
                ),
                const SizedBox(width: 6),
                AppIconButton(
                  icon: LucideIcons.history,
                  tooltip: 'Run History',
                  onPressed: () => onViewHistory(job),
                  size: AppIconButtonSize.sm,
                ),
                const SizedBox(width: 4),
                AppIconButton(
                  icon: LucideIcons.edit,
                  tooltip: 'Edit',
                  onPressed: () => onEdit(job),
                  size: AppIconButtonSize.sm,
                ),
                const SizedBox(width: 4),
                AppIconButton(
                  icon: LucideIcons.trash2,
                  tooltip: 'Delete',
                  color: AppColors.error,
                  onPressed: () => onDelete(job),
                  size: AppIconButtonSize.sm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatLastRun(DateTime? dt) {
    if (dt == null) return '—';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  Widget _buildStatusChip(CronJob job) {
    switch (job.lastStatus) {
      case 'running':
        return const StatusChip(type: StatusType.restarting, label: 'Running');
      case 'success':
        return const StatusChip(type: StatusType.stable, label: 'Success');
      case 'failed':
        return const StatusChip(type: StatusType.stopped, label: 'Failed');
      default:
        return const StatusChip(type: StatusType.warning, label: 'Never');
    }
  }
}
```

- [ ] **Step 4: Write `run_history_modal.dart`**

```dart
// lib/features/cron/presentation/widgets/run_history_modal.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/utils/modal_sizing.dart';
import '../../../../shared/widgets/app_modal_header.dart';
import '../../data/cron_scheduler_service.dart';
import '../../domain/cron_job.dart';

/// Recent runs for one job, newest first. Reads the scheduler's RAM history and
/// re-renders whenever the scheduler reports a state change for the job.
class RunHistoryModal extends StatefulWidget {
  final CronSchedulerService scheduler;
  final CronJob job;

  const RunHistoryModal({
    super.key,
    required this.scheduler,
    required this.job,
  });

  @override
  State<RunHistoryModal> createState() => _RunHistoryModalState();
}

class _RunHistoryModalState extends State<RunHistoryModal> {
  StreamSubscription<int>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.scheduler.statusStream.listen((id) {
      if (mounted && id == widget.job.id) setState(() {});
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dims = modalDimensions(context, ModalSize.lg);
    final records = widget.scheduler.historyFor(widget.job.id);

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: dims.insetPadding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: SizedBox(
        width: dims.width,
        height: dims.height,
        child: Column(
          children: [
            AppModalHeader(
              icon: LucideIcons.history,
              title: 'Run History - ${widget.job.name}',
              subtitle: 'Latest ${records.length} of 20 retained runs (in-memory)',
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: records.isEmpty
                  ? const Center(
                      child: Text(
                        'No runs recorded yet.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppTextSize.sm,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: records.length,
                      itemBuilder: (context, index) =>
                          _buildTile(records[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(RunRecord record) {
    final running = record.exitCode == null;
    final success = record.exitCode == 0;
    final color = running
        ? AppColors.warning
        : (success ? AppColors.success : AppColors.error);
    final label = running ? 'Running' : (success ? 'Success' : 'Failed');

    String duration = '—';
    if (record.finishedAt != null) {
      final ms = record.finishedAt!.difference(record.startedAt).inMilliseconds;
      duration = '${ms} ms';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                running
                    ? LucideIcons.hourglass
                    : (success ? LucideIcons.checkCircle : LucideIcons.xCircle),
                size: 14,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: AppTextSize.xs,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _format(record.startedAt),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppTextSize.xs,
                ),
              ),
              const Spacer(),
              Text(
                duration,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: AppTextSize.xs,
                ),
              ),
            ],
          ),
          if (record.output.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                record.output,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppTextSize.xxs,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _format(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }
}
```

- [ ] **Step 5: Write `cron_form_modal.dart`**

```dart
// lib/features/cron/presentation/widgets/cron_form_modal.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/utils/modal_sizing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_modal_header.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../data/cron_provider.dart';
import '../../domain/cron_expression.dart';
import '../../domain/cron_job.dart';

/// Create/edit form for a cron job: schedule text with quick presets, live
/// validation, and a "next run" preview.
class CronFormModal extends ConsumerStatefulWidget {
  final CronJob? initialJob;

  const CronFormModal({super.key, this.initialJob});

  @override
  ConsumerState<CronFormModal> createState() => _CronFormModalState();
}

class _CronFormModalState extends ConsumerState<CronFormModal> {
  /// Quick presets offered in the dropdown; the value is the cron expression.
  static const Map<String, String> _presets = {
    '*/5 * * * *': 'Every 5 minutes',
    '*/15 * * * *': 'Every 15 minutes',
    '@hourly': 'Hourly',
    '@daily': 'Daily',
    '@weekly': 'Weekly',
    '@monthly': 'Monthly',
  };

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _schedule;
  late final TextEditingController _command;
  late final TextEditingController _workingDir;
  late bool _enabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialJob;
    _name = TextEditingController(text: initial?.name ?? '');
    _schedule = TextEditingController(text: initial?.schedule ?? '@daily');
    _command = TextEditingController(text: initial?.command ?? '');
    _workingDir = TextEditingController(text: initial?.workingDir ?? '');
    _enabled = initial?.enabled ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _schedule.dispose();
    _command.dispose();
    _workingDir.dispose();
    super.dispose();
  }

  Future<void> _pickDirectory() async {
    final path = await FilePicker.getDirectoryPath();
    if (path != null) setState(() => _workingDir.text = path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final isEditing = widget.initialJob != null;
    final job = CronJob(
      id: isEditing ? widget.initialJob!.id : 0,
      name: _name.text.trim(),
      schedule: _schedule.text.trim(),
      command: _command.text.trim(),
      workingDir: _workingDir.text.trim(),
      enabled: _enabled,
      lastRunAt: isEditing ? widget.initialJob!.lastRunAt : null,
      lastStatus: isEditing ? widget.initialJob!.lastStatus : null,
      lastExitCode: isEditing ? widget.initialJob!.lastExitCode : null,
      createdAt: isEditing ? widget.initialJob!.createdAt : DateTime.now(),
    );

    await ref.read(cronRepositoryProvider).save(job);
    if (mounted) Navigator.of(context).pop(job);
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppTextSize.xs,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  String _formatNext(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final dims = modalDimensions(context, ModalSize.lg);
    final isEditing = widget.initialJob != null;

    final scheduleText = _schedule.text.trim();
    final error = CronExpression.validate(scheduleText);
    final preview = error == null
        ? CronExpression.parse(scheduleText).nextOccurrence(DateTime.now())
        : null;
    final presetValue = _presets.containsKey(scheduleText) ? scheduleText : null;

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: dims.insetPadding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: SizedBox(
        width: dims.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppModalHeader(
              icon: LucideIcons.clock,
              title: isEditing ? 'Edit Job: ${widget.initialJob!.name}' : 'New Cron Job',
              subtitle: 'Runs only while DevStack is open — missed runs are not back-filled',
              onClose: () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _label('Name'),
                      AppTextField(
                        controller: _name,
                        hint: 'e.g. nightly-backup',
                        prefixIcon: LucideIcons.tag,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 18),
                      _label('Schedule'),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _schedule,
                              hint: '*/5 * * * * or @daily',
                              prefixIcon: LucideIcons.clock,
                              onChanged: (_) => setState(() {}),
                              validator: (v) =>
                                  CronExpression.validate((v ?? '').trim()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildPresetDropdown(presetValue),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (error != null)
                        Text(
                          error,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: AppTextSize.xxs,
                          ),
                        )
                      else
                        Text(
                          preview == null
                              ? 'No matching time within 4 years.'
                              : 'Next run: ${_formatNext(preview)}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: AppTextSize.xxs,
                          ),
                        ),
                      const SizedBox(height: 18),
                      _label('Command'),
                      AppTextField(
                        controller: _command,
                        hint: 'e.g. php artisan schedule:run',
                        prefixIcon: LucideIcons.terminal,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 18),
                      _label('Working Directory'),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _workingDir,
                              hint: 'e.g. /srv/app (optional)',
                              prefixIcon: LucideIcons.folder,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AppButton(
                            label: 'Browse',
                            style: AppButtonStyle.secondary,
                            icon: const Icon(LucideIcons.folderOpen, size: 14),
                            onPressed: _pickDirectory,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Enabled',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: AppTextSize.sm,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'A disabled job is never scheduled',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: AppTextSize.xxs,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _enabled,
                              activeThumbColor: AppColors.success,
                              onChanged: (v) => setState(() => _enabled = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Cancel',
                    style: AppButtonStyle.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: isEditing ? 'Save Changes' : 'Create Job',
                    style: AppButtonStyle.success,
                    isLoading: _saving,
                    icon: Icon(
                      isEditing ? LucideIcons.save : LucideIcons.plus,
                      size: 16,
                    ),
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetDropdown(String? value) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: const Text(
            'Preset',
            style: TextStyle(
              fontSize: AppTextSize.xs,
              color: AppColors.textMuted,
            ),
          ),
          isExpanded: false,
          dropdownColor: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          style: const TextStyle(
            fontSize: AppTextSize.sm,
            color: AppColors.textPrimary,
          ),
          icon: const Icon(
            LucideIcons.chevronDown,
            size: 16,
            color: AppColors.textMuted,
          ),
          items: _presets.entries
              .map(
                (e) => DropdownMenuItem<String>(
                  value: e.key,
                  child: Text(
                    e.value,
                    style: const TextStyle(
                      fontSize: AppTextSize.sm,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _schedule.text = v);
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Write `cron_page.dart`**

```dart
// lib/features/cron/presentation/cron_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_size.dart';
import '../../../shared/utils/app_dialogs.dart';
import '../../../shared/widgets/app_button.dart';
import '../data/cron_provider.dart';
import '../data/cron_scheduler_service.dart';
import '../domain/cron_job.dart';
import 'widgets/cron_form_modal.dart';
import 'widgets/cron_table.dart';
import 'widgets/run_history_modal.dart';

class CronPage extends ConsumerWidget {
  const CronPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(cronJobsProvider);
    final runningIds = ref.watch(cronRunStateProvider);
    final scheduler = ref.watch(cronSchedulerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            Expanded(
              child: jobsAsync.when(
                data: (jobs) => CronTable(
                  jobs: jobs,
                  runningIds: runningIds,
                  onRunNow: (job) => scheduler.runNow(job),
                  onToggleEnabled: (job) => _toggleEnabled(ref, job),
                  onViewHistory: (job) =>
                      _viewHistory(context, scheduler, job),
                  onEdit: (job) => _edit(context, job),
                  onDelete: (job) => _delete(context, ref, job),
                ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Error loading cron jobs: $e',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cron',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppTextSize.xxl,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Run commands on a schedule while DevStack is open',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppTextSize.sm,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        AppButton(
          label: 'New Job',
          icon: const Icon(LucideIcons.plus, size: 16),
          style: AppButtonStyle.success,
          onPressed: () => _create(context),
        ),
      ],
    );
  }

  Future<void> _toggleEnabled(WidgetRef ref, CronJob job) async {
    job.enabled = !job.enabled;
    await ref.read(cronRepositoryProvider).save(job);
  }

  void _create(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => const Center(child: CronFormModal()),
    );
  }

  void _edit(BuildContext context, CronJob job) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => Center(child: CronFormModal(initialJob: job)),
    );
  }

  void _viewHistory(
    BuildContext context,
    CronSchedulerService scheduler,
    CronJob job,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => RunHistoryModal(scheduler: scheduler, job: job),
    );
  }

  void _delete(BuildContext context, WidgetRef ref, CronJob job) {
    AppDialogs.showConfirm(
      context: context,
      title: 'Delete Job',
      text: 'Delete "${job.name}"? Its configuration will be removed. '
          'This cannot be undone.',
      confirmBtnText: 'DELETE',
      onConfirm: () => ref.read(cronRepositoryProvider).delete(job.id),
    );
  }
}
```

- [ ] **Step 7: Run test + analyze**

Run: `flutter test test/features/cron/presentation/widgets/cron_table_test.dart && flutter analyze lib/features/cron`
Expected: PASS, 0 issues.

- [ ] **Step 8: Commit**

```bash
git add lib/features/cron/presentation test/features/cron/presentation
git commit -m "feat(cron): add cron page, table, form and run-history UI"
```

---

## Task 11: Shared plumbing — navigation, sidebar, routing, auto-start, shutdown

**Files:**
- Modify: `lib/shared/providers/navigation_provider.dart`
- Modify: `lib/shared/layouts/sidebar.dart`
- Modify: `lib/main.dart`
- Modify: `lib/core/services/window_service.dart`
- Test: `test/shared/layouts/sidebar_test.dart`

**Interfaces:**
- Consumes: `SupervisorPage` (Task 9), `CronPage` (Task 10),
  `supervisorManagerProvider` (Task 6), `cronSchedulerProvider` (Task 7).
- Produces:
  - `NavigationTab { apps, sites, databases, tunnels, supervisor, cron, logs, hosts, settings }`.
  - `Sidebar` renders `Supervisor` and `Cron` entries between `Tunnels` and `Logs`.
  - `MainScreen._buildPage` handles the two new tabs; `_MainScreenState` keeps
    the manager/scheduler alive and starts them on launch.
  - `WindowService._quit` and `onWindowClose` stop both subsystems on exit.

- [ ] **Step 1: Write the failing test**

```dart
// test/shared/layouts/sidebar_test.dart
import 'package:dev_stack/shared/layouts/sidebar.dart';
import 'package:dev_stack/shared/providers/navigation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NavigationTab exposes the supervisor and cron tabs', () {
    expect(NavigationTab.values, contains(NavigationTab.supervisor));
    expect(NavigationTab.values, contains(NavigationTab.cron));
  });

  testWidgets('the sidebar renders Supervisor and Cron entries',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: Sidebar())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Supervisor'), findsOneWidget);
    expect(find.text('Cron'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/layouts/sidebar_test.dart`
Expected: FAIL — `NavigationTab.supervisor` / `NavigationTab.cron` do not exist.

- [ ] **Step 3: Add the two tabs to the enum**

In `lib/shared/providers/navigation_provider.dart`, replace the enum line with:

```dart
enum NavigationTab {
  apps,
  sites,
  databases,
  tunnels,
  supervisor,
  cron,
  logs,
  hosts,
  settings,
}
```

No `.g.dart` regeneration is required — the generated code refers to the enum
type, not its members. (Running `dart run build_runner build` is harmless if in
doubt.)

- [ ] **Step 4: Add the two sidebar entries**

In `lib/shared/layouts/sidebar.dart`, insert these two `_buildNavItem` blocks
directly after the `Tunnels` item and before the `Logs` item:

```dart
          _buildNavItem(
            LucideIcons.activity,
            'Supervisor',
            isActive: currentTab == NavigationTab.supervisor,
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setTab(NavigationTab.supervisor),
          ),
          _buildNavItem(
            LucideIcons.clock,
            'Cron',
            isActive: currentTab == NavigationTab.cron,
            onTap: () => ref
                .read(navigationProvider.notifier)
                .setTab(NavigationTab.cron),
          ),
```

- [ ] **Step 5: Wire routing and auto-start in `main.dart`**

Add these imports next to the existing feature imports:

```dart
import 'features/supervisor/presentation/supervisor_page.dart';
import 'features/supervisor/data/supervisor_manager.dart';
import 'features/cron/presentation/cron_page.dart';
import 'features/cron/data/cron_scheduler_service.dart';
```

In `_MainScreenState.initState`, inside the existing
`addPostFrameCallback`, append after the tunnel auto-start loop:

```dart
      // Resolve the Isar provider first: the manager/scheduler resolve Isar
      // lazily, and a read before this future completes would see null and
      // silently start nothing.
      await ref.read(isarProvider.future);
      await ref.read(supervisorManagerProvider).startAutoStart();
      ref.read(cronSchedulerProvider).start();
```

(`isarProvider` is exported by `core/database/isar_provider.dart`, already
imported by `main.dart`.)

In `_MainScreenState.build`, keep both providers alive for the widget's
lifetime — add next to `ref.watch(windowServiceProvider);`:

```dart
    // Keep the supervisor and scheduler alive while the app is open.
    ref.watch(supervisorManagerProvider);
    ref.watch(cronSchedulerProvider);
```

Add the two cases to `_buildPage`:

```dart
      case NavigationTab.supervisor:
        return const SupervisorPage();
      case NavigationTab.cron:
        return const CronPage();
```

- [ ] **Step 6: Stop both subsystems on shutdown**

In `lib/core/services/window_service.dart`, add imports:

```dart
import '../../features/supervisor/data/supervisor_manager.dart';
import '../../features/cron/data/cron_scheduler_service.dart';
```

Then in **both** `_quit()` and the `else` branch of `onWindowClose()`, directly
after the existing `cliProcessManagerProvider` `stopAll()` call, add:

```dart
    // Reap supervised programs and stop the in-app cron scheduler.
    await ref.read(supervisorManagerProvider).stopAll();
    ref.read(cronSchedulerProvider).stop();
```

- [ ] **Step 7: Run test + analyze**

Run: `flutter test test/shared/layouts/sidebar_test.dart && flutter analyze`
Expected: PASS, 0 issues across the whole project.

- [ ] **Step 8: Commit**

```bash
git add lib/shared/providers/navigation_provider.dart lib/shared/layouts/sidebar.dart lib/main.dart lib/core/services/window_service.dart test/shared/layouts/sidebar_test.dart
git commit -m "feat: wire supervisor and cron tabs into navigation, routing and shutdown"
```
