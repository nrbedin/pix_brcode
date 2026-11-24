import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:qr_flutter/qr_flutter.dart';

/// Desenha um QR Code em PNG, com fundo branco, margem e legenda.
///
/// A margem branca (a "quiet zone" do QR) é o que deixa a imagem legível
/// quando aberta em fundo escuro, como no WhatsApp em modo noturno.
class QrImageRenderer {
  /// Cria o renderizador.
  const QrImageRenderer({this.qrSize = 720, this.padding = 64});

  /// Lado do QR, em pixels.
  final double qrSize;

  /// Margem branca em volta do QR e da legenda.
  final double padding;

  static const _titleSize = 56.0;
  static const _subtitleSize = 32.0;
  static const _gap = 24.0;
  static const _textColor = ui.Color(0xFF1B1B1B);

  /// Gera o PNG do QR de [data] com [title] e [subtitle] abaixo.
  Future<Uint8List> renderPng({
    required String data,
    required String title,
    required String subtitle,
  }) async {
    final width = qrSize + padding * 2;
    final titleParagraph = _paragraph(
      title,
      fontSize: _titleSize,
      weight: ui.FontWeight.w600,
      width: qrSize,
    );
    final subtitleParagraph = _paragraph(
      subtitle,
      fontSize: _subtitleSize,
      weight: ui.FontWeight.w400,
      width: qrSize,
    );
    final height = padding +
        qrSize +
        _gap +
        titleParagraph.height +
        subtitleParagraph.height +
        padding;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawRect(
        ui.Rect.fromLTWH(0, 0, width, height),
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      )
      ..save()
      ..translate(padding, padding);
    QrPainter(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      gapless: true,
    ).paint(canvas, ui.Size.square(qrSize));
    canvas
      ..restore()
      ..drawParagraph(
        titleParagraph,
        ui.Offset(padding, padding + qrSize + _gap),
      )
      ..drawParagraph(
        subtitleParagraph,
        ui.Offset(
          padding,
          padding + qrSize + _gap + titleParagraph.height,
        ),
      );

    final image =
        await recorder.endRecording().toImage(width.ceil(), height.ceil());
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  ui.Paragraph _paragraph(
    String text, {
    required double fontSize,
    required ui.FontWeight weight,
    required double width,
  }) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: ui.TextAlign.center,
        maxLines: 2,
        ellipsis: '…',
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: _textColor,
        fontSize: fontSize,
        fontWeight: weight,
      ))
      ..addText(text);
    return builder.build()..layout(ui.ParagraphConstraints(width: width));
  }
}
