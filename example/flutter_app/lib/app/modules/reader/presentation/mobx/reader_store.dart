import 'package:mobx/mobx.dart';

import 'reader_state.dart';

part 'reader_store.g.dart';

/// Estado observável da tela de leitura.
class ReaderStore = ReaderStoreBase with _$ReaderStore;

/// Base do [ReaderStore], usada pelo mobx_codegen.
abstract class ReaderStoreBase with Store {
  /// Estado atual.
  @observable
  ReaderState state = const ReaderIdle();

  /// Troca o estado.
  @action
  void setState(ReaderState value) => state = value;
}
