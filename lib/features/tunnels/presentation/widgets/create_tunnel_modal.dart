import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_modal_header.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/tunnel_model.dart';
import '../../data/tunnel_manager_service.dart';
import '../../../sites/data/sites_provider.dart';

class CreateTunnelModal extends ConsumerStatefulWidget {
  final TunnelModel? initialTunnel;

  const CreateTunnelModal({super.key, this.initialTunnel});

  @override
  ConsumerState<CreateTunnelModal> createState() => _CreateTunnelModalState();
}

class _CreateTunnelModalState extends ConsumerState<CreateTunnelModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _targetSiteDomainController;
  late final TextEditingController _targetPortController;
  late final TextEditingController _authTokenController;
  late final TextEditingController _customDomainController;

  late String _targetType;
  late String _provider;
  late bool _autoStart;
  bool _isCustomSite = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTunnel;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _targetSiteDomainController =
        TextEditingController(text: initial?.targetSiteDomain ?? '');
    _targetPortController =
        TextEditingController(text: initial?.targetPort.toString() ?? '80');
    _authTokenController = TextEditingController(text: initial?.authToken ?? '');
    _customDomainController =
        TextEditingController(text: initial?.customDomain ?? '');

    _targetType = initial?.targetType ?? 'site';
    _provider = initial?.provider ?? 'cloudflare';
    _autoStart = initial?.autoStart ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetSiteDomainController.dispose();
    _targetPortController.dispose();
    _authTokenController.dispose();
    _customDomainController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final isEditing = widget.initialTunnel != null;
    final tunnel = TunnelModel(
      id: isEditing ? widget.initialTunnel!.id : 0, // isar_plus: 0 signals auto-increment
      name: _nameController.text.trim(),
      provider: _provider,
      targetType: _targetType,
      targetSiteDomain: _targetType == 'site'
          ? _targetSiteDomainController.text.trim()
          : null,
      targetPort: int.tryParse(_targetPortController.text) ?? 80,
      authToken: _authTokenController.text.trim().isEmpty
          ? null
          : _authTokenController.text.trim(),
      customDomain: _customDomainController.text.trim().isEmpty
          ? null
          : _customDomainController.text.trim(),
      autoStart: _autoStart,
      createdAt:
          isEditing ? widget.initialTunnel!.createdAt : DateTime.now(),
      lastActiveAt:
          isEditing ? widget.initialTunnel!.lastActiveAt : null,
    );

    await ref.read(tunnelManagerServiceProvider).saveTunnel(tunnel);
    if (mounted) {
      Navigator.of(context).pop(tunnel);
    }
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: AppTextSize.xs,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sitesAsync = ref.watch(sitesProvider);

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppModalHeader(
              icon: LucideIcons.cloud,
              title: widget.initialTunnel == null
                  ? 'Create Tunnel'
                  : 'Edit Tunnel: ${widget.initialTunnel!.name}',
              subtitle: widget.initialTunnel == null
                  ? 'Expose local services to the internet securely'
                  : 'Update tunnel configuration and routing',
              onClose: () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Tunnel Name
                      _buildLabel('Tunnel Name'),
                      AppTextField(
                        controller: _nameController,
                        hint: 'e.g. my-project-tunnel',
                        prefixIcon: LucideIcons.cloud,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 18),

                      // Target type + Provider row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Target Type'),
                                _buildTargetTypeToggle(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Provider'),
                                _buildProviderDropdown(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Target-specific field
                      if (_targetType == 'site') ...[
                        _buildLabel('Target Site'),
                        _buildTargetSiteField(sitesAsync),
                      ] else ...[
                        _buildLabel('Target Port'),
                        AppTextField(
                          controller: _targetPortController,
                          hint: 'e.g. 80, 3000, 8080',
                          prefixIcon: LucideIcons.hash,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            final n = int.tryParse(v.trim());
                            if (n == null || n < 1 || n > 65535) {
                              return 'Enter a valid port (1-65535)';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 18),

                      // Auth token
                      _buildLabel('Auth Token (Optional)'),
                      AppTextField(
                        controller: _authTokenController,
                        hint: 'Token from Cloudflare or Ngrok dashboard',
                        prefixIcon: LucideIcons.key,
                        obscureText: true,
                      ),
                      const SizedBox(height: 18),

                      // Custom domain
                      _buildLabel('Custom Domain (Optional)'),
                      AppTextField(
                        controller: _customDomainController,
                        hint: 'e.g. tunnel.mydomain.com',
                        prefixIcon: LucideIcons.globe,
                      ),
                      const SizedBox(height: 18),

                      // Auto start toggle card
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.playCircle,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Auto start on app launch',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: AppTextSize.sm,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Automatically connect when DevStack opens',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: AppTextSize.xxs,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _autoStart,
                              activeThumbColor: AppColors.success,
                              onChanged: (v) => setState(() => _autoStart = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                    style: AppButtonStyle.ghost,
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: widget.initialTunnel == null
                        ? 'Create Tunnel'
                        : 'Save Changes',
                    onPressed: _save,
                    style: AppButtonStyle.success,
                    icon: Icon(
                      widget.initialTunnel == null
                          ? LucideIcons.plus
                          : LucideIcons.save,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetTypeToggle() {
    Widget buildType(String label, String value, IconData icon) {
      final selected = _targetType == value;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _targetType = value),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: AppTextSize.sm,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        buildType('Site', 'site', LucideIcons.globe),
        const SizedBox(width: 8),
        buildType('Port', 'port', LucideIcons.hash),
      ],
    );
  }

  Widget _buildProviderDropdown() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _provider,
          isExpanded: true,
          style: const TextStyle(
            fontSize: AppTextSize.sm,
            color: AppColors.textPrimary,
          ),
          dropdownColor: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          icon: const Icon(
            LucideIcons.chevronDown,
            size: 16,
            color: AppColors.textMuted,
          ),
          items: const [
            DropdownMenuItem(
              value: 'cloudflare',
              child: Row(
                children: [
                  Icon(
                    LucideIcons.cloud,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Cloudflare',
                    style: TextStyle(
                      fontSize: AppTextSize.sm,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'ngrok',
              child: Row(
                children: [
                  Icon(
                    LucideIcons.zap,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Ngrok',
                    style: TextStyle(
                      fontSize: AppTextSize.sm,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _provider = v);
          },
        ),
      ),
    );
  }

  Widget _buildTargetSiteField(AsyncValue<List<dynamic>> sitesAsync) {
    final siteDomains = sitesAsync.when(
      data: (sites) => sites.map<String>((s) => s.domain as String).toList(),
      loading: () => <String>[],
      error: (e, st) => <String>[],
    );

    final currentText = _targetSiteDomainController.text.trim();
    if (_isCustomSite || (siteDomains.isEmpty && currentText.isNotEmpty)) {
      return Row(
        children: [
          Expanded(
            child: AppTextField(
              controller: _targetSiteDomainController,
              hint: 'e.g. my-app.test',
              prefixIcon: LucideIcons.globe,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
          ),
          if (siteDomains.isNotEmpty) ...[
            const SizedBox(width: 8),
            AppButton(
              label: 'Sites',
              style: AppButtonStyle.secondary,
              icon: const Icon(LucideIcons.list, size: 14),
              onPressed: () {
                setState(() {
                  _isCustomSite = false;
                  if (siteDomains.isNotEmpty) {
                    _targetSiteDomainController.text = siteDomains.first;
                  }
                });
              },
            ),
          ],
        ],
      );
    }

    final items = <String>[...siteDomains];
    if (currentText.isNotEmpty && !items.contains(currentText)) {
      items.insert(0, currentText);
    }

    final selectedValue = items.contains(currentText)
        ? currentText
        : (items.isNotEmpty ? items.first : null);
    if (_targetSiteDomainController.text.isEmpty && selectedValue != null) {
      _targetSiteDomainController.text = selectedValue;
    }

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(_targetSiteDomainController.text)
              ? _targetSiteDomainController.text
              : null,
          hint: const Text(
            'Select a local site',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: AppTextSize.sm,
            ),
          ),
          isExpanded: true,
          style: const TextStyle(
            fontSize: AppTextSize.sm,
            color: AppColors.textPrimary,
          ),
          dropdownColor: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          icon: const Icon(
            LucideIcons.chevronDown,
            size: 16,
            color: AppColors.textMuted,
          ),
          items: [
            ...items.map(
              (d) => DropdownMenuItem(
                value: d,
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.globe,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        d,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppTextSize.sm,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const DropdownMenuItem<String>(
              value: '__custom__',
              child: Row(
                children: [
                  Icon(
                    LucideIcons.plus,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '+ Custom domain...',
                    style: TextStyle(
                      fontSize: AppTextSize.sm,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          onChanged: (v) {
            if (v == null) return;
            if (v == '__custom__') {
              setState(() {
                _isCustomSite = true;
                _targetSiteDomainController.clear();
              });
            } else {
              setState(() {
                _targetSiteDomainController.text = v;
              });
            }
          },
        ),
      ),
    );
  }
}
