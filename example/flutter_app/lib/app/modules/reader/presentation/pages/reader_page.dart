import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../reader_module.dart';
import '../controller/reader_controller.dart';
import '../mobx/reader_state.dart';
import '../widgets/parse_error_view.dart';
import '../widgets/reading_view.dart';

/// Tela para ler um BR Code: pela câmera ou colando o "copia e cola".
class ReaderPage extends StatefulWidget {
  /// Cria a tela.
  const ReaderPage({super.key});

  /// Caminho completo da tela, para navegar até ela.
  static const path = '/reader/';

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  final _controller = Modular.get<ReaderController>();
  final _text = TextEditingController();

  void _read(String value) {
    _text.text = value;
    FocusScope.of(context).unfocus();
    _controller.read(value);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    _read(data?.text ?? '');
  }

  Future<void> _scan() async {
    final raw = await Modular.to.pushNamed<String>(
      '/reader${ReaderModule.scanRoute}',
    );
    if (raw != null && mounted) _read(raw);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ler QR Code Pix')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    key: const Key('scan'),
                    onPressed: _scan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Escanear com a câmera'),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    key: const Key('brcode-field'),
                    controller: _text,
                    minLines: 3,
                    maxLines: 6,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      labelText: 'Pix copia e cola',
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        key: const Key('paste'),
                        tooltip: 'Colar',
                        onPressed: _paste,
                        icon: const Icon(Icons.content_paste),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    key: const Key('read'),
                    onPressed: () => _read(_text.text),
                    child: const Text('Ler código'),
                  ),
                  const SizedBox(height: 24),
                  Observer(
                    builder: (_) => switch (_controller.store.state) {
                      ReaderIdle(:final message?) => Text(
                          message,
                          key: const Key('idle-message'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ReaderIdle() => const SizedBox.shrink(),
                      ReaderDecoded(:final reading) =>
                        ReadingView(reading: reading),
                      ReaderInvalid(:final source, :final error) =>
                        ParseErrorView(source: source, error: error),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
