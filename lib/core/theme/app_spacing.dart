/// The app's spacing scale, in 4px steps.
///
/// Every gap, inset and padding is one of these. The list stops at [xl] on
/// purpose: a 20 or 24px inset that needs its own name is usually a layout
/// decision (a card's inner padding) rather than a step on the scale, and
/// giving it a token would hide that it is larger than the rhythm around it.
class AppSpacing {
  /// Hairline separation between two labels in one block.
  static const double xxs = 4.0;

  /// A gap inside a control: an icon and its label.
  static const double xs = 6.0;

  /// The common gap between controls in a row, and a block's first inset.
  static const double sm = 8.0;

  /// The gap between two groups of controls, and the padding of a container.
  static const double md = 12.0;

  /// The inset of a card or a toolbar.
  static const double lg = 16.0;

  /// The breathing room around a page's content.
  static const double xl = 24.0;
}
