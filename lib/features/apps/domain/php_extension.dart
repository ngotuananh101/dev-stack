/// A PHP extension as presented in the app-settings Extensions tab.
///
/// The first five fields are shared by every platform. The last three are
/// Linux-only: on Windows an extension is always already on disk next to the
/// PHP binary and is never installed by a package manager, so [isInstalled]
/// defaults to `true` and [packageName] / [description] stay null.
class PhpExtension {
  final String name;

  /// 'mbstring.so' on Linux, 'php_mbstring.dll' on Windows.
  final String fileName;
  final bool isEnabled;
  final bool isFoundInIni;
  final bool isZend;

  /// Linux only — whether the extension's `.so` exists in `extension_dir`.
  final bool isInstalled;

  /// Linux only — e.g. 'php8.5-mbstring'. Null on Windows.
  final String? packageName;

  /// Linux only — the package manager's one-line description. Null on Windows.
  final String? description;

  const PhpExtension({
    required this.name,
    required this.fileName,
    required this.isEnabled,
    required this.isFoundInIni,
    required this.isZend,
    this.isInstalled = true,
    this.packageName,
    this.description,
  });

  PhpExtension copyWith({
    bool? isEnabled,
    bool? isInstalled,
    String? packageName,
    String? description,
  }) {
    return PhpExtension(
      name: name,
      fileName: fileName,
      isEnabled: isEnabled ?? this.isEnabled,
      isFoundInIni: isFoundInIni,
      isZend: isZend,
      isInstalled: isInstalled ?? this.isInstalled,
      packageName: packageName ?? this.packageName,
      description: description ?? this.description,
    );
  }
}
