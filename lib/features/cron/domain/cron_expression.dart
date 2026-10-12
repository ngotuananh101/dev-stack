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