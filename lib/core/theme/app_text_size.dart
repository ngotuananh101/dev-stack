/// The app's type scale.
///
/// The steps are fixed: 8, 10, 12, 14, 16, 18. What matters is which step a
/// role reads at, and the app as a whole reads at [xs] (12): table cells, table
/// headers, form fields, button labels, modal titles, dialogs and status chips
/// all sit there. Hierarchy in those places comes from weight and colour,
/// because a dense desktop tool set at three sizes in one row reads as noise.
///
/// A page title is the one surface a step above the body: it reads at [sm]
/// (14), bold, and its one-line description stays at [xs]. The steps above
/// [sm] are reserved for a feature banner's statistic and for Material's own
/// display roles.
class AppTextSize {
  static const double xxxxxs = 6.0;

  /// A tight badge on a pill too small for anything else.
  static const double xxxs = 8.0;

  /// Meta text under a row: a schedule's description, a version's build
  /// number, a saturated extension's tags.
  static const double xxs = 10.0;

  /// The size the app reads at.
  static const double xs = 12.0;

  /// A page title and a feature card's headline — one per screen, never body
  /// copy.
  static const double sm = 14.0;
  static const double base = 16.0;
  static const double md = 16.0;
  static const double lg = 18.0;
  static const double xl = 20.0;

  /// A feature banner's statistic, such as the module count.
  static const double xxl = 24.0;
  static const double xxxl = 28.0;
  static const double xxxxl = 32.0;
}
