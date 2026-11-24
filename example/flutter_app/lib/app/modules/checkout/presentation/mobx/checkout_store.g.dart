// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checkout_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$CheckoutStore on CheckoutStoreBase, Store {
  Computed<bool>? _$canCancelComputed;

  @override
  bool get canCancel =>
      (_$canCancelComputed ??= Computed<bool>(() => super.canCancel,
              name: 'CheckoutStoreBase.canCancel'))
          .value;

  late final _$stateAtom =
      Atom(name: 'CheckoutStoreBase.state', context: context);

  @override
  CheckoutState get state {
    _$stateAtom.reportRead();
    return super.state;
  }

  @override
  set state(CheckoutState value) {
    _$stateAtom.reportWrite(value, super.state, () {
      super.state = value;
    });
  }

  late final _$CheckoutStoreBaseActionController =
      ActionController(name: 'CheckoutStoreBase', context: context);

  @override
  void setState(CheckoutState value) {
    final _$actionInfo = _$CheckoutStoreBaseActionController.startAction(
        name: 'CheckoutStoreBase.setState');
    try {
      return super.setState(value);
    } finally {
      _$CheckoutStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
state: ${state},
canCancel: ${canCancel}
    ''';
  }
}
