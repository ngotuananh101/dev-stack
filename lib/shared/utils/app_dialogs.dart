import 'package:material_ui/material_ui.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'app_alert.dart';
import 'package:toastification/toastification.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_size.dart';
import 'modal_sizing.dart';

/// The app's two notification shapes.
///
/// Anything the user does not have to stop for — a finished operation, a value
/// copied, a step that merely started — is a toast from `toastification`. An
/// error is something they have to read and acknowledge, so it is a
/// material_ui modal with QuickAlert's illustration assets. Neither uses
/// `ScaffoldMessenger`: a `SnackBar` is
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
  }) async {
    final confirmed = await showAppAlert(
      context: context,
      type: type,
      title: title,
      message: text,
      confirmText: confirmBtnText,
      cancelText: cancelBtnText,
      confirmColor: type == QuickAlertType.warning
          ? AppColors.errorStrong
          : AppColors.successStrong,
    );
    if (confirmed == true) onConfirm();
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
  }) async {
    await showAppAlert(
      context: context,
      type: QuickAlertType.error,
      title: title,
      message: message,
      confirmText: 'CLOSE',
      confirmColor: AppColors.error,
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

  /// Asks the user to allow a command that needs administrator rights, naming
  /// exactly what will run. Returns true only when they confirm.
  ///
  /// The command is shown as-is rather than described, because the prompt is
  /// the user's chance to see what is about to happen before the system
  /// authentication dialog appears.
  static Future<bool> showPermissionRequest(
    BuildContext context, {
    required String title,
    required String message,
    required String command,
  }) async {
    final confirmed = await showAppAlert(
      context: context,
      type: QuickAlertType.confirm,
      title: title,
      message: message,
      detail: Container(
        width: kModalWidthSm,
        margin: const EdgeInsets.only(top: AppSpacing.md),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: SelectableText(
          command,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppTextSize.xs,
            fontFamily: 'monospace',
          ),
        ),
      ),
      confirmText: 'ALLOW',
      cancelText: 'CANCEL',
      confirmColor: AppColors.successStrong,
    );
    // Barrier, back, and cancellation all deny permission; only ALLOW (or the
    // focused dialog's Enter shortcut) answers true.
    return confirmed == true;
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
      // Top right, under the app's own title bar: a toast anchored at the
      // bottom would sit against the window edge and cover the footer, far
      // from where the user is looking after an action.
      alignment: Alignment.topRight,
      title: Text(
        message,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppTextSize.xs,
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
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      autoCloseDuration: const Duration(seconds: 3),
      closeButton: const ToastCloseButton(showType: CloseButtonShowType.none),
      showProgressBar: false,
      sizeConstraints: const BoxConstraints(minHeight: 0),
    );
  }
}
