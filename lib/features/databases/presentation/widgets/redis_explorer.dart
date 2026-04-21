import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/redis_key.dart';
import '../../data/redis_provider.dart';
import '../../../apps/domain/app_model.dart';

class RedisExplorer extends ConsumerStatefulWidget {
  final AppModel app;

  const RedisExplorer({super.key, required this.app});

  @override
  ConsumerState<RedisExplorer> createState() => _RedisExplorerState();
}

class _RedisExplorerState extends ConsumerState<RedisExplorer> {
  int _selectedDb = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  void _refresh() {
    ref.read(redisNotifierProvider.notifier).fetchKeys(
      widget.app, 
      _selectedDb, 
      query: _searchController.text
    );
  }

  @override
  Widget build(BuildContext context) {
    final keysAsync = ref.watch(redisNotifierProvider);
    final statsAsync = ref.watch(redisDbStatsProvider(widget.app));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildToolbar(),
        const SizedBox(height: 16),
        _buildDbTabs(statsAsync.asData?.value ?? {}),
        const SizedBox(height: 16),
        _buildSearchAndFeedback(),
        const SizedBox(height: 16),
        Expanded(
          child: keysAsync.when(
            data: (keys) => _buildKeysTable(keys),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        _buildToolbarButton('Add Key', LucideIcons.plus, color: AppColors.success),
        const SizedBox(width: 8),
        _buildToolbarButton('Remote DB', LucideIcons.globe),
        const SizedBox(width: 8),
        _buildToolbarButton('Backup list', LucideIcons.list),
        const SizedBox(width: 8),
        _buildToolbarButton('Clear DB', LucideIcons.trash2, onTap: () => _handleClearDb()),
        const Spacer(),
        _buildStatusCapsule(),
      ],
    );
  }

  Widget _buildToolbarButton(String label, IconData icon, {Color? color, VoidCallback? onTap}) {
    return ElevatedButton.icon(
      onPressed: onTap ?? () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AppColors.surfaceLight,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildStatusCapsule() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            'Redis ${widget.app.installedVersion ?? "N/A"}',
            style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const Icon(LucideIcons.play, size: 12, color: AppColors.error),
        ],
      ),
    );
  }

  Widget _buildDbTabs(Map<int, int> stats) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(16, (index) {
          final isSelected = _selectedDb == index;
          final count = stats[index] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() => _selectedDb = index);
                _refresh();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.surfaceLight : AppColors.surface,
                  border: Border.all(color: isSelected ? AppColors.accent : AppColors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'DB$index($count)',
                  style: TextStyle(
                    color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSearchAndFeedback() {
    return Row(
      children: [
        Icon(LucideIcons.messageSquare, size: 16, color: AppColors.success),
        const SizedBox(width: 8),
        const Text('Feedback', style: TextStyle(color: AppColors.success, fontSize: 12)),
        const Spacer(),
        SizedBox(
          width: 300,
          height: 36,
          child: TextField(
            controller: _searchController,
            onSubmitted: (_) => _refresh(),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search key',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              suffixIcon: IconButton(
                icon: const Icon(LucideIcons.search, size: 14),
                onPressed: _refresh,
              ),
              filled: true,
              fillColor: AppColors.surface,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
      ],
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
              itemBuilder: (context, index) => _buildTableRow(keys[index], index == keys.length - 1),
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
          const SizedBox(width: 24), // Checkbox placeholder
          Expanded(flex: 3, child: _buildHeaderCell('Key')),
          Expanded(flex: 4, child: _buildHeaderCell('Value')),
          Expanded(flex: 1, child: _buildHeaderCell('Data type')),
          Expanded(flex: 1, child: _buildHeaderCell('Data length')),
          Expanded(flex: 2, child: _buildHeaderCell('Term of validity')),
          Expanded(flex: 1, child: _buildHeaderCell('Operate', alignment: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, {TextAlign alignment = TextAlign.left}) {
    return Text(
      label,
      textAlign: alignment,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
    );
  }

  Widget _buildTableRow(RedisKey item, bool isLast) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.square, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(item.key, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12), overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 4,
            child: Text(item.value, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 1,
            child: Text(item.type, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          Expanded(
            flex: 1,
            child: Text(item.length.toString(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          Expanded(
            flex: 2,
            child: Text(item.ttl, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildActionText('Edit', AppColors.success, () {}),
                const SizedBox(width: 12),
                _buildActionText('Delete', AppColors.error, () => _handleDeleteKey(item.key)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionText(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  void _handleDeleteKey(String key) async {
    await ref.read(redisNotifierProvider.notifier).deleteKey(widget.app, _selectedDb, key);
  }

  void _handleClearDb() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Database'),
        content: Text('Are you sure you want to clear all keys in DB$_selectedDb?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(redisNotifierProvider.notifier).clearDb(widget.app, _selectedDb);
    }
  }
}
