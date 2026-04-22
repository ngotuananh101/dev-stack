import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dev_stack/core/theme/app_colors.dart';
import 'package:dev_stack/core/theme/app_text_size.dart';
import 'package:dev_stack/shared/utils/app_dialogs.dart';
import '../../domain/database_record.dart';

class DatabaseTable extends StatelessWidget {
  final List<DatabaseRecord> databases;
  final String engineId;
  final Function(DatabaseRecord) onDelete;

  const DatabaseTable({
    super.key, 
    required this.databases,
    required this.engineId,
    required this.onDelete,
  });

  bool get isRedis => engineId.contains('redis');

  @override
  Widget build(BuildContext context) {
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
            ...databases.asMap().entries.map((entry) {
              final index = entry.key;
              final db = entry.value;
              return _buildTableRow(context, db, index == databases.length - 1);
            }),
        ],
      ),
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

  Widget _buildTableRow(BuildContext context, DatabaseRecord db, bool isLast) {
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
                  style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold),
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
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildActionIconButton(
                    icon: Icons.refresh_rounded,
                    onPressed: () {},
                    color: AppColors.accent,
                    tooltip: 'Flush DB',
                  ),
                  const SizedBox(width: 8),
                  _buildActionIconButton(
                    icon: Icons.delete_outline_rounded,
                    onPressed: () => onDelete(db),
                    color: AppColors.error,
                    tooltip: 'Clear Record',
                  ),
                ],
              ),
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
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildActionIconButton(
                    icon: Icons.tune_rounded,
                    onPressed: () {},
                    color: AppColors.textSecondary,
                    tooltip: 'Manage',
                  ),
                  const SizedBox(width: 8),
                  _buildActionIconButton(
                    icon: Icons.delete_outline_rounded,
                    onPressed: () => onDelete(db),
                    color: AppColors.error,
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ),
          ],
      ),
    );
  }

  Widget _buildActionIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              border: Border.all(color: AppColors.border, width: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
        ),
      ),
    );
  }
}
