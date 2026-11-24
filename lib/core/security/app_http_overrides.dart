import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:dev_stack/core/services/log_service.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// `CERT_CONTEXT` layout from WinCrypt (`wincrypt.h`).
final class _CertContext extends Struct {
  @Uint32()
  external int dwCertEncodingType;

  external Pointer<Uint8> pbCertEncoded;

  @Uint32()
  external int cbCertEncoded;

  external Pointer<Void> pCertInfo;

  external Pointer<Void> hCertStore;
}

typedef _GetProcessHeapNative = Pointer<Void> Function();
typedef _GetProcessHeapDart = Pointer<Void> Function();

typedef _HeapAllocNative =
    Pointer<Uint8> Function(
      Pointer<Void> hHeap,
      Uint32 dwFlags,
      Size dwBytes,
    );
typedef _HeapAllocDart =
    Pointer<Uint8> Function(Pointer<Void> hHeap, int dwFlags, int dwBytes);

typedef _HeapFreeNative =
    Int32 Function(Pointer<Void> hHeap, Uint32 dwFlags, Pointer<Void> lpMem);
typedef _HeapFreeDart =
    int Function(Pointer<Void> hHeap, int dwFlags, Pointer<Void> lpMem);

typedef _CertOpenSystemStoreANative =
    Pointer<Void> Function(
      IntPtr hProv,
      Pointer<Uint8> szSubsystemProtocol,
    );
typedef _CertOpenSystemStoreADart =
    Pointer<Void> Function(int hProv, Pointer<Uint8> szSubsystemProtocol);

typedef _CertEnumCertificatesInStoreNative =
    Pointer<_CertContext> Function(
      Pointer<Void> hCertStore,
      Pointer<_CertContext> pPrevCertContext,
    );
typedef _CertEnumCertificatesInStoreDart =
    Pointer<_CertContext> Function(
      Pointer<Void> hCertStore,
      Pointer<_CertContext> pPrevCertContext,
    );

typedef _CertFreeCertificateContextNative =
    Int32 Function(Pointer<_CertContext> pCertContext);
typedef _CertFreeCertificateContextDart =
    int Function(Pointer<_CertContext> pCertContext);

typedef _CertCloseStoreNative =
    Int32 Function(Pointer<Void> hCertStore, Uint32 dwFlags);
typedef _CertCloseStoreDart =
    int Function(Pointer<Void> hCertStore, int dwFlags);

/// Global [HttpOverrides] that augments Dart's built-in root CAs with the
/// host OS trust store (Windows Certificate Store / Linux CA bundles) and
/// optionally honors the user's "Ignore SSL Certificate Errors" setting.
class AppHttpOverrides extends HttpOverrides {
  static const int _x509AsnEncoding = 0x1;

  static const List<String> _linuxDefaultCaBundles = [
    '/etc/ssl/certs/ca-certificates.crt',
    '/etc/pki/tls/certs/ca-bundle.crt',
    '/etc/ssl/ca-bundle.pem',
    '/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem',
  ];

  static bool _allowInsecureSsl = false;

  /// Whether outgoing HTTPS connections should bypass certificate verification.
  static bool get allowInsecureSsl => _allowInsecureSsl;

  /// Updates the global insecure-SSL toggle immediately without needing an app
  /// restart; existing [Dio] / [HttpClient] instances inspect this on each new
  /// TLS handshake via `badCertificateCallback`.
  static void setAllowInsecureSsl(bool value) {
    _allowInsecureSsl = value;
  }

  final SecurityContext? _securityContext;

  AppHttpOverrides._(this._securityContext);

  /// Installs [AppHttpOverrides] as [HttpOverrides.global] using a cached
  /// [SecurityContext] augmented with OS root certificates.
  static void install({bool allowInsecureSsl = false}) {
    _allowInsecureSsl = allowInsecureSsl;
    final context = buildSecurityContext();
    HttpOverrides.global = AppHttpOverrides._(context);
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context ?? _securityContext);
    // Read `_allowInsecureSsl` dynamically so toggling the preference in
    // Settings takes effect right away for already-constructed Dio clients.
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) => _allowInsecureSsl;
    return client;
  }

  /// Builds a [SecurityContext] starting from Dart's bundled trusted roots and
  /// adding trusted CA certificates from the host OS when available.
  static SecurityContext? buildSecurityContext() {
    try {
      final context = SecurityContext(withTrustedRoots: true);

      if (Platform.isWindows) {
        final pemCerts = _readWindowsCertStores(
          logWarning: (msg) => AppLogger.warning(msg),
        );
        loadPemCertificatesIntoContext(
          context,
          pemCerts,
          logWarning: (msg) => AppLogger.warning(msg),
        );
      } else if (Platform.isLinux) {
        final envCertFile = Platform.environment['SSL_CERT_FILE']?.trim();
        final candidates = resolveLinuxCaBundlePaths();
        var standardBundleLoaded = false;

        for (final path in candidates) {
          final isEnvOverride =
              envCertFile != null &&
              envCertFile.isNotEmpty &&
              path == envCertFile;
          if (!isEnvOverride && standardBundleLoaded) {
            continue;
          }

          try {
            final file = File(path);
            if (!file.existsSync() || file.lengthSync() == 0) continue;
            context.setTrustedCertificates(path);
            if (!isEnvOverride || _linuxDefaultCaBundles.contains(path)) {
              standardBundleLoaded = true;
            }
          } catch (e) {
            AppLogger.warning('Failed to load Linux CA bundle "$path": $e');
          }
        }
      }

      return context;
    } catch (e) {
      AppLogger.warning('Failed to load OS root certificates: $e');
      return null;
    }
  }

  /// Resolves ordered, deduplicated Linux CA bundle file paths, prioritizing
  /// `SSL_CERT_FILE` when set.
  @visibleForTesting
  static List<String> resolveLinuxCaBundlePaths({
    Map<String, String>? environment,
  }) {
    final env = environment ?? Platform.environment;
    final seen = <String>{};
    final paths = <String>[];

    final envCertFile = env['SSL_CERT_FILE']?.trim();
    if (envCertFile != null &&
        envCertFile.isNotEmpty &&
        seen.add(envCertFile)) {
      paths.add(envCertFile);
    }

    for (final candidate in _linuxDefaultCaBundles) {
      if (seen.add(candidate)) {
        paths.add(candidate);
      }
    }

    return paths;
  }

  /// Converts a DER-encoded X.509 certificate into PEM format.
  @visibleForTesting
  static String derToPem(Uint8List derBytes) {
    final encoded = base64.encode(derBytes);
    final buffer = StringBuffer('-----BEGIN CERTIFICATE-----\n');
    for (var i = 0; i < encoded.length; i += 64) {
      final end = (i + 64 < encoded.length) ? i + 64 : encoded.length;
      buffer
        ..write(encoded.substring(i, end))
        ..write('\n');
    }
    buffer.write('-----END CERTIFICATE-----\n');
    return buffer.toString();
  }

  /// Loads [pemCerts] into [context], trying a single bulk load first and
  /// falling back per-certificate so one malformed cert cannot block the rest.
  @visibleForTesting
  static int loadPemCertificatesIntoContext(
    SecurityContext context,
    List<String> pemCerts, {
    void Function(String)? logWarning,
  }) {
    if (pemCerts.isEmpty) return 0;

    try {
      final combined = utf8.encode(pemCerts.join('\n'));
      context.setTrustedCertificatesBytes(combined);
      return pemCerts.length;
    } catch (e) {
      logWarning?.call(
        'Bulk OS certificate load failed, falling back to per-certificate loading: $e',
      );
    }

    var loaded = 0;
    for (final pem in pemCerts) {
      try {
        context.setTrustedCertificatesBytes(utf8.encode(pem));
        loaded++;
      } catch (e) {
        logWarning?.call('Skipping unreadable OS certificate: $e');
      }
    }
    return loaded;
  }

  static List<String> _readWindowsCertStores({
    List<String> storeNames = const ['ROOT', 'CA'],
    void Function(String)? logWarning,
  }) {
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final crypt32 = DynamicLibrary.open('crypt32.dll');

    final getProcessHeap = kernel32
        .lookupFunction<_GetProcessHeapNative, _GetProcessHeapDart>(
          'GetProcessHeap',
        );
    final heapAlloc = kernel32
        .lookupFunction<_HeapAllocNative, _HeapAllocDart>('HeapAlloc');
    final heapFree = kernel32.lookupFunction<_HeapFreeNative, _HeapFreeDart>(
      'HeapFree',
    );

    final certOpenSystemStoreA = crypt32
        .lookupFunction<_CertOpenSystemStoreANative, _CertOpenSystemStoreADart>(
          'CertOpenSystemStoreA',
        );
    final certEnumCertificatesInStore = crypt32
        .lookupFunction<
          _CertEnumCertificatesInStoreNative,
          _CertEnumCertificatesInStoreDart
        >('CertEnumCertificatesInStore');
    final certFreeCertificateContext = crypt32
        .lookupFunction<
          _CertFreeCertificateContextNative,
          _CertFreeCertificateContextDart
        >('CertFreeCertificateContext');
    final certCloseStore = crypt32
        .lookupFunction<_CertCloseStoreNative, _CertCloseStoreDart>(
          'CertCloseStore',
        );

    final hHeap = getProcessHeap();
    if (hHeap == nullptr) {
      logWarning?.call('GetProcessHeap returned null');
      return const [];
    }

    final pemCerts = <String>[];

    for (final storeName in storeNames) {
      final nameBytes = ascii.encode(storeName);
      final namePtr = heapAlloc(hHeap, 0, nameBytes.length + 1);
      if (namePtr == nullptr) {
        logWarning?.call(
          'HeapAlloc failed for Windows cert store "$storeName"',
        );
        continue;
      }

      Pointer<Void> store = nullptr;
      Pointer<_CertContext> current = nullptr;

      try {
        final buffer = namePtr.asTypedList(nameBytes.length + 1);
        buffer.setAll(0, nameBytes);
        buffer[nameBytes.length] = 0;

        store = certOpenSystemStoreA(0, namePtr);
        if (store == nullptr) {
          logWarning?.call(
            'CertOpenSystemStoreA failed for store "$storeName"',
          );
          continue;
        }

        while (true) {
          // CertEnumCertificatesInStore frees `current` when advancing.
          final next = certEnumCertificatesInStore(store, current);
          current = next;
          if (current == nullptr) break;

          final ref = current.ref;
          if ((ref.dwCertEncodingType & _x509AsnEncoding) != 0 &&
              ref.pbCertEncoded != nullptr &&
              ref.cbCertEncoded > 0) {
            // Copy DER bytes before the next enumeration frees this context.
            final derBytes = Uint8List.fromList(
              ref.pbCertEncoded.asTypedList(ref.cbCertEncoded),
            );
            pemCerts.add(derToPem(derBytes));
          }
        }
      } catch (e) {
        logWarning?.call('Failed to read Windows "$storeName" store: $e');
      } finally {
        if (current != nullptr) {
          certFreeCertificateContext(current);
        }
        if (store != nullptr) {
          certCloseStore(store, 0);
        }
        heapFree(hHeap, 0, namePtr.cast<Void>());
      }
    }

    return pemCerts;
  }
}
