import 'package:pix_brcode/pix_brcode.dart';

import '../../domain/services/brcode_inspector.dart';
import '../mobx/reader_state.dart';
import '../mobx/reader_store.dart';

/// Regras da tela de leitura de BR Code.
class ReaderController {
  /// Cria o controller.
  ReaderController(this.store,
      {BrCodeInspector inspector = const BrCodeInspector()})
      : _inspector = inspector;

  /// Estado observável da tela.
  final ReaderStore store;

  final BrCodeInspector _inspector;

  /// Lê [text], vindo da câmera ou colado pelo usuário.
  void read(String text) {
    final source = text.trim();
    if (source.isEmpty) {
      store.setState(
        const ReaderIdle(message: 'Cole um código Pix ou escaneie um QR.'),
      );
      return;
    }
    try {
      store.setState(ReaderDecoded(_inspector.inspect(source)));
    } on PixParseException catch (error) {
      store.setState(ReaderInvalid(source: source, error: error));
    }
  }

  /// Volta para o estado inicial.
  void clear() => store.setState(const ReaderIdle());
}
