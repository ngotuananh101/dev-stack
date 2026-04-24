import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/redis_key.dart';
import '../../../apps/domain/app_model.dart';
import '../../data/redis_provider.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:dev_stack/shared/utils/app_dialogs.dart';
import 'add_redis_key_modal.dart';

class RedisExplorer extends ConsumerStatefulWidget {
  final AppModel app;
  final String? searchQuery;
  final int selectedDb;
  final Function(int) onDbChanged;

  const RedisExplorer({
    super.key,
    required this.app,
    this.searchQuery,
    required this.selectedDb,
    required this.onDbChanged,
  });

  @override
  ConsumerState<RedisExplorer> createState() => _RedisExplorerState();
}

class _RedisExplorerState extends ConsumerState<RedisExplorer> {
  final ScrollController _dbScrollController = ScrollController();

  @override
  void dispose() {
    _dbScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(RedisExplorer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.selectedDb != widget.selectedDb) {
      _refresh();
    }
  }

  void _refresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final query = widget.searchQuery ?? '';
      ref
          .read(redisNotifierProvider.notifier)
          .fetchKeys(
            widget.app,
            widget.selectedDb,
            query: query.isEmpty ? '*' : '*$query*',
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final keysAsync = ref.watch(redisNotifierProvider);
    final statsAsync = ref.watch(redisDbStatsProvider(widget.app));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        statsAsync.when(
          data: (stats) => _buildDbTabs(stats),
          loading: () => const SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const SizedBox(height: 48),
        ),
        const SizedBox(height: 16),
        Expanded(
          flex: 1,
          child: keysAsync.when(
            data: (keys) => _buildKeysTable(keys),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text(
                err.toString(),
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDbTabs(Map<int, int> stats) {
    return SizedBox(
      height: 48,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: Scrollbar(
          controller: _dbScrollController,
          thickness: 3,
          radius: const Radius.circular(4),
          child: ListView.builder(
            controller: _dbScrollController,
            padding: const EdgeInsets.only(bottom: 8),
            scrollDirection: Axis.horizontal,
            itemCount: 16,
            itemBuilder: (context, index) {
              final isSelected = widget.selectedDb == index;
              final count = stats[index] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: InkWell(
                  onTap: () => widget.onDbChanged(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.surfaceLight
                          : AppColors.surface,
                      border: Border.all(
                        color: isSelected ? AppColors.accent : AppColors.border,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'DB$index($count)',
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildKeysTable(List<RedisKey> keys) {
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
          Expanded(
            child: ListView.builder(
              itemCount: keys.length,
              itemBuilder: (context, index) =>
                  _buildTableRow(keys[index], index == keys.length - 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: _buildHeaderCell('KEY')),
          const SizedBox(width: 12),
          Expanded(flex: 4, child: _buildHeaderCell('VALUE')),
          const SizedBox(width: 12),
          Expanded(flex: 1, child: _buildHeaderCell('DATA TYPE')),
          const SizedBox(width: 12),
          Expanded(flex: 1, child: _buildHeaderCell('DATA LENGTH')),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: _buildHeaderCell('TERM OF VALIDITY')),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: _buildHeaderCell('OPERATE', alignment: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
    String label, {
    TextAlign alignment = TextAlign.left,
  }) {
    return Text(
      label,
      textAlign: alignment,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTableRow(RedisKey item, bool isLast) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              item.key,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              item.value,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: Text(
              item.type,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: Text(
              item.length.toString(),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              item.ttl,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildIconButton(
                  icon: Icons.edit_outlined,
                  onPressed: () => _handleEditKey(item),
                  color: AppColors.textSecondary,
                  tooltip: 'Edit',
                ),
                const SizedBox(width: 8),
                _buildIconButton(
                  icon: Icons.delete_outline_rounded,
                  onPressed: () => _handleDeleteKey(item.key),
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

  Widget _buildIconButton({
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

  void _handleDeleteKey(String key) {
    AppDialogs.showConfirm(
      context: context,
      title: 'Delete Key',
      text: 'Are you sure you want to delete key "$key"?',
      confirmBtnText: 'DELETE',
      onConfirm: () async {
        await ref
            .read(redisNotifierProvider.notifier)
            .deleteKey(widget.app, widget.selectedDb, key);
      },
    );
  }

  void _handleEditKey(RedisKey item) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Center(
        child: AddRedisKeyModal(
          engine: widget.app,
          dbIndex: widget.selectedDb,
          initialKey: item.key,
          initialValue: item.value,
          initialTtl: item.rawTtl,
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }
}
