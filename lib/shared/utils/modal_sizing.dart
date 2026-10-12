import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Canonical widths for the app's modals, one per [ModalSize] tier.
///
/// The values follow the widths already in use across the app so existing
/// dialogs map onto a tier without drifting: alerts/confirmations sit at
/// [kModalWidthSm], standard forms at [kModalWidthMd], richer forms at
/// [kModalWidthLg], and log viewers / settings panels at [kModalWidthXl].
const double kModalWidthSm = 420;
const double kModalWidthMd = 560;
const double kModalWidthLg = 720;
const double kModalWidthXl = 900;

/// Canonical heights for the tiers that have a fixed height. [ModalSize.sm]
/// deliberately has none — an alert or a short form sizes to its content.
const double kModalHeightMd = 600;
const double kModalHeightLg = 640;
const double kModalHeightXl = 720;

/// Inset a modal leaves around itself, matching the app's existing dialogs.
const EdgeInsets kModalInsetPadding = EdgeInsets.symmetric(
  horizontal: 24,
  vertical: 24,
);

/// Fraction of the window height a modal may occupy before it stops growing.
const double kModalMaxHeightFraction = 0.85;

/// Extra breathing room kept between the dialog's outer edge and the body.
const double _kModalGutter = 16;

/// A standard modal size tier.
///
/// - [sm]: alerts, confirmations, and short forms (auto height).
/// - [md]: the default form modal.
/// - [lg]: forms with many fields.
/// - [xl]: log viewers and settings panels.
/// - [full]: a full-screen modal that fills the entire window.
enum ModalSize { sm, md, lg, xl, full }

/// The resolved geometry for a modal: how wide and tall it should be, and how
/// much inset to leave around it. Produced by [modalDimensions].
@immutable
class ModalDimensions {
  const ModalDimensions({
    required this.size,
    required this.width,
    required this.height,
    required this.insetPadding,
  });

  /// The tier this geometry was resolved from.
  final ModalSize size;

  /// Resolved width in logical pixels, never wider than the window allows.
  final double width;

  /// Resolved height, or `null` when the modal should size to its content
  /// ([ModalSize.sm]).
  final double? height;

  /// Inset to pass to the enclosing [Dialog]. [EdgeInsets.zero] for a
  /// full-screen modal.
  final EdgeInsets insetPadding;

  /// Whether this is a full-screen modal, which fills the window and drops its
  /// rounded border/inset.
  bool get isFullscreen => size == ModalSize.full;
}

/// Resolves the [ModalSize] tier into concrete geometry for [context].
///
/// Widths shrink to fit a narrow window (minus [kModalInsetPadding] and a small
/// gutter) so a modal never overflows; heights are capped at
/// [kModalMaxHeightFraction] of the window. [ModalSize.full] ignores both caps
/// and fills the entire window.
ModalDimensions modalDimensions(BuildContext context, ModalSize size) {
  final window = MediaQuery.sizeOf(context);

  if (size == ModalSize.full) {
    return ModalDimensions(
      size: ModalSize.full,
      width: window.width,
      height: window.height,
      insetPadding: EdgeInsets.zero,
    );
  }

  final availableWidth = math.max(
    0.0,
    window.width - kModalInsetPadding.horizontal - _kModalGutter,
  );
  final width = math.min(_baseWidth(size), availableWidth);

  final baseHeight = _baseHeight(size);
  final height = baseHeight == null
      ? null
      : math.min(baseHeight, window.height * kModalMaxHeightFraction);

  return ModalDimensions(
    size: size,
    width: width,
    height: height,
    insetPadding: kModalInsetPadding,
  );
}

double _baseWidth(ModalSize size) {
  switch (size) {
    case ModalSize.sm:
      return kModalWidthSm;
    case ModalSize.md:
      return kModalWidthMd;
    case ModalSize.lg:
      return kModalWidthLg;
    case ModalSize.xl:
      return kModalWidthXl;
    // Unreachable: [modalDimensions] returns early for a full-screen modal.
    case ModalSize.full:
      return double.infinity;
  }
}

double? _baseHeight(ModalSize size) {
  switch (size) {
    case ModalSize.sm:
      return null;
    case ModalSize.md:
      return kModalHeightMd;
    case ModalSize.lg:
      return kModalHeightLg;
    case ModalSize.xl:
      return kModalHeightXl;
    // Unreachable: [modalDimensions] returns early for a full-screen modal.
    case ModalSize.full:
      return double.infinity;
  }
}
