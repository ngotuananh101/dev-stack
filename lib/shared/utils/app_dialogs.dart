import 'package:flutter/material.dart';
import 'package:quickalert/quickalert.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_size.dart';

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
      confirmBtnColor: type == QuickAlertType.warning ? AppColors.error : AppColors.primary,
      width: 420,
      confirmBtnTextStyle: const TextStyle(
        color: Colors.white,
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

  static Future<void> showSuccess({
    required BuildContext context,
    required String title,
    required String text,
  }) {
    return QuickAlert.show(
      context: context,
      type: QuickAlertType.success,
      title: title,
      text: text,
      confirmBtnText: 'OK',
      confirmBtnColor: AppColors.success,
      backgroundColor: AppColors.surface,
      titleColor: AppColors.textPrimary,
      textColor: AppColors.textSecondary,
      width: 420,
      confirmBtnTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: AppTextSize.xs,
        fontWeight: FontWeight.w700,
      ),
    );
  }

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
      width: 420,
      confirmBtnTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: AppTextSize.xs,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  static Future<void> showInfo({
    required BuildContext context,
    required String title,
    required String text,
  }) {
    return QuickAlert.show(
      context: context,
      type: QuickAlertType.info,
      title: title,
      text: text,
      confirmBtnText: 'OK',
      confirmBtnColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      titleColor: AppColors.textPrimary,
      textColor: AppColors.textSecondary,
      width: 420,
      confirmBtnTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: AppTextSize.xs,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
