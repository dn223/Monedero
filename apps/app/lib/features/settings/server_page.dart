import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:monedero_core/monedero_core.dart';

import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';
import '../../core/config/server_settings.dart';
import '../../core/providers.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/qr.dart';

/// Elegir el servidor sin recompilar: pegar o escanear el link que imprime
/// `dart run tool/share.dart` (o la IP de la laptop en la misma Wi-Fi).
class ServerPage extends ConsumerStatefulWidget {
  /// Crea la pantalla.
  const ServerPage({super.key});

  /// Ruta.
  static const path = '/servidor';

  @override
  ConsumerState<ServerPage> createState() => _ServerPageState();
}

class _ServerPageState extends ConsumerState<ServerPage> {
  late final _url = TextEditingController(text: ref.read(serverUrlProvider));
  bool _busy = false;
  Object? _error;
  HealthStatus? _ok;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _testAndSave(String raw) async {
    final url = QrPayloads.serverUrl(raw);
    if (url == null) {
      setState(
        () => _error = const ApiException(
          'Escribe una dirección como https://algo.trycloudflare.com o '
          'http://192.168.1.50:8080',
        ),
      );
      return;
    }
    _url.text = url;
    setState(() {
      _busy = true;
      _error = null;
      _ok = null;
    });
    try {
      final health = await ApiClient(
        baseUrl: url,
        httpClient: ref.read(httpClientProvider),
      ).health();
      await ref.read(serverUrlProvider.notifier).set(url);
      ref.invalidate(apiHealthProvider);
      setState(() => _ok = health);
    } on ApiException catch (error) {
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final raw = await scanQr(context, title: 'Escanea el QR del link');
    if (raw != null) await _testAndSave(raw);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = ref.watch(serverUrlProvider);
    final custom = ref.read(serverUrlProvider.notifier).isCustom;
    return RoleScaffold(
      title: 'Servidor',
      icon: Icons.dns_rounded,
      maxWidth: 520,
      body: PageList(
        children: [
          const SizedBox(height: 8),
          Text(
            '¿A qué servidor se conecta?',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Pega o escanea el link de la exposición (el que imprime '
            'dart run tool/share.dart). Las sesiones abiertas se cierran al '
            'cambiar de servidor.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          InfoPanel(
            icon: Icons.link_rounded,
            child: Text('Ahora: $current${custom ? '' : ' (predeterminado)'}'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            onSubmitted: _testAndSave,
            decoration: const InputDecoration(
              labelText: 'Dirección del servidor',
              hintText: 'https://algo.trycloudflare.com',
              prefixIcon: Icon(Icons.public_rounded),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : () => _testAndSave(_url.text),
            child: Text(_busy ? 'Probando…' : 'Probar y guardar'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _scan,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Escanear QR del link'),
          ),
          if (custom)
            TextButton(
              onPressed: () async {
                await ref.read(serverUrlProvider.notifier).reset();
                _url.text = AppConfig.apiBaseUrl;
                ref.invalidate(apiHealthProvider);
              },
              child: Text('Volver a ${AppConfig.apiBaseUrl}'),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorPanel(_error!),
          ],
          if (_ok != null) ...[
            const SizedBox(height: 12),
            InfoPanel(
              icon: Icons.check_circle_rounded,
              child: Text(
                'Conectado (versión ${_ok!.version}'
                '). Guardado.',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
