import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dev_stack/core/theme/app_colors.dart';
import 'package:dev_stack/core/theme/app_text_size.dart';
import 'package:dev_stack/shared/utils/action_row_layout.dart';
import 'package:dev_stack/shared/utils/app_dialogs.dart';
import 'package:dev_stack/shared/widgets/row_action_menu.dart';
import '../../domain/database_record.dart';

class DatabaseTable extends StatelessWidget {
  final List<DatabaseRecord> databases;
  final String engineId;
  final Function(DatabaseRecord) onDelete;
  final Function(DatabaseRecord) onEdit;

  const DatabaseTable({
    super.key, 
    required this.databases,
    required this.engineId,
    required this.onDelete,
    required this.onEdit,
  });

  bool get isRedis => engineId.contains('redis');

  @override
  Widget build(BuildContext context) {
    // The row's action cluster needs the width it really has, so the table
    // measures itself instead of assuming a window width.
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildTableHeader(),
              if (databases.isEmpty)
                _buildNoData()
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: databases.length,
                    itemBuilder: (context, index) => _buildTableRow(
                      context,
                      availableWidth,
                      databases[index],
                      index == databases.length - 1,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoData() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              'No Data',
              style: TextStyle(color: AppColors.textMuted, fontSize: AppTextSize.sm),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: isRedis 
        ? [
            Expanded(flex: 1, child: _buildHeaderCell('DB INDEX')),
            Expanded(flex: 1, child: _buildHeaderCell('STATUS')),
            Expanded(flex: 3, child: _buildHeaderCell('NOTE')),
            Expanded(flex: 1, child: _buildHeaderCell('OPERATE', alignment: TextAlign.right)),
          ]
        : [
            Expanded(flex: 2, child: _buildHeaderCell('DATABASE NAME')),
            Expanded(flex: 1, child: _buildHeaderCell('USERNAME')),
            Expanded(flex: 1, child: _buildHeaderCell('PASSWORD')),
            Expanded(flex: 2, child: _buildHeaderCell('NOTE')),
            Expanded(flex: 1, child: _buildHeaderCell('OPERATE', alignment: TextAlign.right)),
          ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, {TextAlign alignment = TextAlign.left}) {
    return Text(
      label,
      textAlign: alignment,
      style: const TextStyle(
        fontSize: AppTextSize.xxs,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.5,
      ),
    );
  }

  /// Floor for one flexible data column, below which its text is ellipsized to
  /// uselessness.
  static const double _flexColumnMinWidth = 150;

  /// Width the OPERATE menu cannot grow into: the row padding plus the floor of
  /// every flexible data column. The redis row carries one column fewer, so it
  /// keeps its actions inline further down than the SQL row does — that is the
  /// intended difference, not a shared breakpoint.
  double get _operateReservedWidth =>
      16 * 2 + _flexColumnMinWidth * (isRedis ? 3 : 4);

  Widget _buildTableRow(
    BuildContext context,
    double availableWidth,
    DatabaseRecord db,
    bool isLast,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: isRedis 
        ? [
            Expanded(
              flex: 1,
              child: Text(
                db.name.toUpperCase(),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.xs, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(color: AppColors.success, fontSize: AppTextSize.xxs, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                db.note ?? '-',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.xs),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            RowActionMenu(
              availableWidth: availableWidth - _operateReservedWidth,
              gap: 8,
              actions: [
                RowAction.icon(
                  'Flush DB',
                  () {},
                  icon: Icons.refresh_rounded,
                ),
                RowAction.icon(
                  'Clear Record',
                  () => onDelete(db),
                  icon: Icons.delete_outline_rounded,
                ),
              ],
            ),
          ]
        : [
            Expanded(
              flex: 2,
              child: Text(
                db.name,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: AppTextSize.xs, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                db.username,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.xs),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      db.password.isEmpty ? '-' : '********',
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppTextSize.xs),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (db.password.isNotEmpty)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: db.password));
                          AppDialogs.showToast(context, 'Password copied!');
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                db.note ?? '-',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.xs),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            RowActionMenu(
              availableWidth: availableWidth - _operateReservedWidth,
              gap: 8,
              actions: [
                RowAction.icon(
                  'Edit Database',
                  () => onEdit(db),
                  icon: Icons.edit_outlined,
                ),
                RowAction.icon(
                  'Delete',
                  () => onDelete(db),
                  icon: Icons.delete_outline_rounded,
                ),
              ],
            ),
          ],
      ),
    );
  }

}
