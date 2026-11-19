import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quickalert/models/quickalert_type.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_size.dart';
import 'modal_sizing.dart';

/// Uses the app's Material library throughout, while preserving QuickAlert's
/// bundled illustrations. Mixing Flutter's legacy AlertDialog with material_ui
/// requires two incompatible localization/theme trees and an SDK-private import.
Future<bool?> showAppAlert({
  required BuildContext context,
  required QuickAlertType type,
  required String title,
  required String message,
  required String confirmText,
  required Color confirmColor,
  String? cancelText,
  Widget? detail,
}) {
  var answered = false;
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      void answer(bool value) {
        if (answered || !dialogContext.mounted) return;
        // A dismissing route remains mounted until its exit animation finishes.
        // Never let a late click or key event pop the route underneath it.
        if (ModalRoute.of(dialogContext)?.isCurrent != true) return;
        answered = true;
        Navigator.of(dialogContext).pop(value);
      }

      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): () => answer(true),
          const SingleActivator(LogicalKeyboardKey.escape): () => answer(false),
        },
        child: Focus(
          autofocus: true,
          child: AlertDialog(
            backgroundColor: AppColors.surface,
            contentPadding: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            content: SizedBox(
              width: kModalWidthSm,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 150,
                      child: Image.asset(
                        'packages/quickalert/assets/${type == QuickAlertType.custom ? 'info' : type.name}.gif',
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: AppTextSize.xs,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: AppTextSize.xs,
                            ),
                          ),
                          ?detail,
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (cancelText != null) ...[
                                Flexible(
                                  child: TextButton(
                                    onPressed: () => answer(false),
                                    child: Text(
                                      cancelText,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: AppTextSize.xs,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    backgroundColor: confirmColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.md,
                                      ),
                                    ),
                                  ),
                                  onPressed: () => answer(true),
                                  child: Text(
                                    confirmText,
                                    style: const TextStyle(
                                      color: AppColors.textOnColor,
                                      fontSize: AppTextSize.xs,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
