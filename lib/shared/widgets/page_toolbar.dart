import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// A page toolbar laid out as `[actions …] [search field]`.
///
/// The actions wrap onto a second line when the window is narrow, while the
/// search field stays pinned to the toolbar's right edge.
///
/// This is a widget rather than a bare `Row` because of how `RenderFlex`
/// hands out free space: it splits the leftover width evenly between *every*
/// flex child. Pairing an `Expanded` action group with a `Flexible` search
/// field therefore gives the field only half the leftover width; the action
/// group cannot grow past its buttons, so the other half becomes a dead gap
/// and the field stops short of the right edge — which reads on screen as a
/// clipped toolbar. Giving the field an explicit width here leaves the action
/// group as the only flex child, so it absorbs the whole gap.
class PageToolbar extends StatelessWidget {
  const PageToolbar({
    super.key,
    required this.actions,
    required this.searchField,
  });

  /// Buttons shown at the left, inside the wrap. Add any fixed-width control
  /// that belongs between the buttons and the search field here too, in the
  /// order it should appear: the wrap lays them out in a line whenever there is
  /// room and moves them onto a second line when there is not, so a control
  /// left outside the wrap could not shrink and would overflow instead.
  final List<Widget> actions;

  /// The search field, whose width the toolbar chooses.
  final Widget searchField;

  /// The search field's width when the window is wide enough.
  static const double maxSearchWidth = 280;

  /// The narrowest the search field is allowed to get. Below this it stops
  /// shrinking and the actions wrap instead.
  static const double minSearchWidth = 180;

  /// Space between the actions and the search field.
  static const double gap = 12;

  /// Width the action group keeps for itself before the search field starts
  /// giving up width. Two buttons side by side fit in this.
  static const double minActionsWidth = 320;

  static const double _runSpacing = 8;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The field keeps its full width while the actions have room to wrap
        // into; only once they would be squeezed past [minActionsWidth] does
        // the field give up width, down to [minSearchWidth].
        final fieldWidth = math
            .min(maxSearchWidth, constraints.maxWidth - minActionsWidth)
            .clamp(minSearchWidth, maxSearchWidth);

        return Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: gap,
                runSpacing: _runSpacing,
                children: actions,
              ),
            ),
            const SizedBox(width: gap),
            SizedBox(width: fieldWidth, child: searchField),
          ],
        );
      },
    );
  }
}
