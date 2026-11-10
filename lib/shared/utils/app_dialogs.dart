import 'package:flutter/material.dart';
import 'package:quickalert/quickalert.dart';
import 'package:toastification/toastification.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_size.dart';
import 'modal_sizing.dart';

/// The app's two notification shapes.
///
/// Anything the user does not have to stop for — a finished operation, a value
/// copied, a step that merely started — is a toast from `toastification`. An
/// error is something they have to read and acknowledge, so it is a
/// `quickalert` modal. Neither uses `ScaffoldMessenger`: a `SnackBar` is
/// anchored to the `Scaffold` that owns it, so it disappears when a dialog
/// closes over it, which is exactly when these messages are emitted.
class AppDialogs {
  static Future<void> showConfirm({
    required BuildContext context,
    required String title,
    required String text,
    required VoidCallback onConfirm,
    String confirmBtnText = 'CONFIRM',
    String cancelBtnText = 'CLOSE',
    QuickAlertType type = QuickAlertType.warning,
  }) {
    return QuickAlert.show(
      context: context,
      type: type,
      title: title,
      text: text,
      confirmBtnText: confirmBtnText,
      cancelBtnText: cancelBtnText,
      showCancelBtn: true,
      onConfirmBtnTap: () {
        Navigator.of(context).pop();
        onConfirm();
      },
      backgroundColor: AppColors.surface,
      titleColor: AppColors.textPrimary,
      textColor: AppColors.textSecondary,
      confirmBtnColor: type == QuickAlertType.warning
          ? AppColors.errorStrong
          : AppColors.successStrong,
      width: kModalWidthSm,
      confirmBtnTextStyle: const TextStyle(
        color: AppColors.textOnColor,
        fontSize: AppTextSize.xs,
        fontWeight: FontWeight.w700,
      ),
      cancelBtnTextStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: AppTextSize.xs,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// A short success confirmation: a file saved, a value copied, an operation
  /// that finished. It does not take the focus away from what the user is
  /// doing; an error is something they have to acknowledge, so it goes to
  /// [showError] instead.
  static void showToast(BuildContext context, String message) {
    _showToast(context, message: message, type: ToastificationType.success);
  }

  /// A short neutral message: something started, a value was copied. Unlike an
  /// error it needs no acknowledgement, so it is a toast and not [showError].
  static void showInfoToast(BuildContext context, String message) {
    _showToast(context, message: message, type: ToastificationType.info);
  }

  /// Shows [message] as a modal error the user has to dismiss.
  ///
  /// Use this for anything the user must read: a failed write, a rejected
  /// input, a failed install. For a message that merely reports what happened,
  /// use [showToast] or [showInfoToast].
  static Future<void> showError(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return QuickAlert.show(
      context: context,
      type: QuickAlertType.error,
      title: title,
      text: message,
      confirmBtnText: 'CLOSE',
      confirmBtnColor: AppColors.error,
      backgroundColor: AppColors.surface,
      titleColor: AppColors.textPrimary,
      textColor: AppColors.textSecondary,
      width: kModalWidthSm,
      confirmBtnTextStyle: const TextStyle(
        color: AppColors.textOnColor,
        fontSize: AppTextSize.xs,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  /// A one-line call site for the common `Error: $e` reports. The title stays
  /// generic so the exception text keeps the user's whole attention.
  static Future<void> showErrorFrom(
    BuildContext context,
    Object error, {
    String title = 'Something went wrong',
  }) {
    return showError(context, title: title, message: '$error');
  }

  /// One toast shape for every non-blocking message: the app's palette on the
  /// app's own surface. The package's stock styles take their background from
  /// `Colors.white`/`Colors.black` regardless of the app's brightness, so the
  /// colors are passed explicitly instead of being themed.
  static void _showToast(
    BuildContext context, {
    required String message,
    required ToastificationType type,
  }) {
    final isSuccess = type == ToastificationType.success;
    final accent = isSuccess ? AppColors.success : AppColors.info;

    toastification.show(
      context: context,
      type: type,
      style: ToastificationStyle.flat,
      alignment: Alignment.bottomRight,
      title: Text(
        message,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppTextSize.sm,
          fontWeight: FontWeight.w500,
        ),
      ),
      icon: Icon(
        isSuccess ? Icons.check_circle_outline : Icons.info_outline,
        size: 20,
        color: accent,
      ),
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      primaryColor: accent,
      borderSide: const BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.circular(AppRadius.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTextSize.base,
        vertical: AppTextSize.xs,
      ),
      autoCloseDuration: const Duration(seconds: 3),
      closeButton: const ToastCloseButton(showType: CloseButtonShowType.none),
      showProgressBar: false,
      sizeConstraints: const BoxConstraints(minHeight: 0),
    );
  }
}
