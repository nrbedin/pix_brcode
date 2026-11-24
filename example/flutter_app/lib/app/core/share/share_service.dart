import 'dart:typed_data';
import 'dart:ui';

import 'package:share_plus/share_plus.dart';

/// Abre a folha de compartilhamento do sistema.
///
/// Fica atrás de uma interface para os testes não dependerem do plugin.
abstract interface class ShareService {
  /// Compartilha a imagem [png] como [fileName], com [text] junto.
  ///
  /// [origin] é a área do botão na tela; no iPad, a folha abre apontando
  /// para ela.
  Future<void> shareImage({
    required Uint8List png,
    required String fileName,
    String? text,
    Rect? origin,
  });
}

/// [ShareService] com o `share_plus`.
class SharePlusShareService implements ShareService {
  /// Cria o serviço.
  const SharePlusShareService();

  @override
  Future<void> shareImage({
    required Uint8List png,
    required String fileName,
    String? text,
    Rect? origin,
  }) async {
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(png, mimeType: 'image/png', name: fileName)],
      fileNameOverrides: [fileName],
      text: text,
      sharePositionOrigin: origin,
      // No navegador sem Web Share API, baixa o arquivo.
      downloadFallbackEnabled: true,
    ));
  }
}
