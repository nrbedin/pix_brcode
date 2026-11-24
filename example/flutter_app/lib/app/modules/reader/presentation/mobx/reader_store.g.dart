// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ReaderStore on ReaderStoreBase, Store {
  late final _$stateAtom =
      Atom(name: 'ReaderStoreBase.state', context: context);

  @override
  ReaderState get state {
    _$stateAtom.reportRead();
    return super.state;
  }

  @override
  set state(ReaderState value) {
    _$stateAtom.reportWrite(value, super.state, () {
      super.state = value;
    });
  }

  late final _$ReaderStoreBaseActionController =
      ActionController(name: 'ReaderStoreBase', context: context);

  @override
  void setState(ReaderState value) {
    final _$actionInfo = _$ReaderStoreBaseActionController.startAction(
        name: 'ReaderStoreBase.setState');
    try {
      return super.setState(value);
    } finally {
      _$ReaderStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
state: ${state}
    ''';
  }
}
