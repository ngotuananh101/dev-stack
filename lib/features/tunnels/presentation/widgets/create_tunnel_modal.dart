import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_size.dart';
import '../../../../shared/widgets/app_button.dart';
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.surfaceLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    );
  }

  TextStyle get _inputStyle =>
      const TextStyle(color: AppColors.textPrimary);

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
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.initialTunnel == null
                      ? 'Create Tunnel'
                      : 'Edit Tunnel: ${widget.initialTunnel!.name}',
                  style: const TextStyle(
                    fontSize: AppTextSize.lg,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x,
                      size: 18, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Name
                  AppTextField(
                    controller: _nameController,
                    hint: 'Name',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Target type + Provider row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Target',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: AppTextSize.xs)),
                            const SizedBox(height: 6),
                            _buildTargetTypeToggle(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Provider',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: AppTextSize.xs)),
                            const SizedBox(height: 6),
                            _buildProviderDropdown(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Target-specific field
                  _buildTargetField(sitesAsync),
                  const SizedBox(height: 16),

                  // Auth token
                  AppTextField(
                    controller: _authTokenController,
                    hint: 'Auth Token (optional)',
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),

                  // Custom domain
                  AppTextField(
                    controller: _customDomainController,
                    hint: 'Custom Domain (optional)',
                  ),
                  const SizedBox(height: 16),

                  // Auto start toggle
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Auto start on app launch',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: AppTextSize.sm,
                          ),
                        ),
                      ),
                      Switch(
                        value: _autoStart,
                        onChanged: (v) => setState(() => _autoStart = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                  style: AppButtonStyle.ghost,
                  size: AppButtonSize.md,
                ),
                const SizedBox(width: 12),
                AppButton(
                  label: widget.initialTunnel == null ? 'Create' : 'Save',
                  onPressed: _save,
                  style: AppButtonStyle.primary,
                  size: AppButtonSize.md,
                  icon: const Icon(LucideIcons.save, size: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetTypeToggle() {
    Widget buildType(String label, String value) {
      final selected = _targetType == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _targetType = value),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : null,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border),
            ),
            child: Center(
              child: Text(
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
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        buildType('Site', 'site'),
        const SizedBox(width: 8),
        buildType('Port', 'port'),
      ],
    );
  }

  Widget _buildProviderDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _provider,
      dropdownColor: AppColors.surfaceLight,
      decoration: _inputDecoration('Provider'),
      style: _inputStyle,
      items: const [
        DropdownMenuItem(value: 'cloudflare', child: Text('Cloudflare')),
        DropdownMenuItem(value: 'ngrok', child: Text('Ngrok')),
      ],
      onChanged: (v) => setState(() => _provider = v ?? 'cloudflare'),
    );
  }

  Widget _buildTargetField(AsyncValue<List<dynamic>> sitesAsync) {
    if (_targetType == 'site') {
      final siteDomains = sitesAsync.when(
        data: (sites) => sites.map<String>((s) => s.domain).toList(),
        loading: () => <String>[],
        error: (e, s) => <String>[],
      );

      // Build the dropdown items: existing sites plus any custom value already entered.
      final items = <String>[...siteDomains];
      final currentText = _targetSiteDomainController.text.trim();
      if (currentText.isNotEmpty && !items.contains(currentText)) {
        items.insert(0, currentText);
      }

      final currentValue = items.contains(currentText) ? currentText : null;

      return DropdownButtonFormField<String>(
        initialValue: currentValue,
        dropdownColor: AppColors.surfaceLight,
        decoration: _inputDecoration('Site domain'),
        style: _inputStyle,
        items: [
          ...items.map((d) => DropdownMenuItem(
              value: d, child: Text(d, style: _inputStyle))),
          const DropdownMenuItem<String>(
            value: '__custom__',
            child: Text('+ Custom...',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
        onChanged: (v) {
          if (v == null) return;
          if (v == '__custom__') {
            setState(() {
              _targetSiteDomainController.clear();
            });
          } else {
            setState(() {
              _targetSiteDomainController.text = v;
            });
          }
        },
        validator: (v) => currentText.isEmpty ? 'Required' : null,
        disabledHint: sitesAsync.when(
          data: (_) => const Text('Select a domain'),
          loading: () => const Text('Loading...'),
          error: (e, s) => const Text('Error loading sites'),
        ),
      );
    }

    // targetType == 'port'
    return AppTextField(
      controller: _targetPortController,
      hint: 'Target Port',
      keyboardType: TextInputType.number,
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Required';
        final n = int.tryParse(v.trim());
        if (n == null || n < 1 || n > 65535) {
          return 'Enter a valid port (1-65535)';
        }
        return null;
      },
    );
  }
}
