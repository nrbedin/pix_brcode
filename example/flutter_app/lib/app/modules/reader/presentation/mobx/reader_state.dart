import 'package:pix_brcode/pix_brcode.dart';

import '../../domain/entities/brcode_reading.dart';

/// Estados da tela de leitura.
sealed class ReaderState {
  const ReaderState();
}

/// Nada lido ainda. [message] pede um código quando o campo estava vazio.
final class ReaderIdle extends ReaderState {
  /// Cria o estado.
  const ReaderIdle({this.message});

  /// Aviso para o usuário, se houver.
  final String? message;
}

/// Código lido e válido.
final class ReaderDecoded extends ReaderState {
  /// Cria o estado.
  const ReaderDecoded(this.reading);

  /// O que foi lido.
  final BrCodeReading reading;
}

/// O texto não é um BR Code Pix válido.
final class ReaderInvalid extends ReaderState {
  /// Cria o estado.
  const ReaderInvalid({required this.source, required this.error});

  /// O texto lido, sem espaços nas pontas.
  final String source;

  /// O erro do pix_brcode, com o campo e a posição.
  final PixParseException error;
}
