/// A minimal stand-in for `package:flutterbloc_kit`: the BuildContext
/// extensions and a BlocBuilder with a typed builder, so closures infer a
/// BuildContext parameter the way they do against the real package.
library;

const flutterblocStub = r'''
library flutterbloc_kit;

import 'package:dartnative/dartnative.dart';

abstract class BlocBase<S> {
  S get state;
}

class Cubit<S> extends BlocBase<S> {
  Cubit(this._state);
  S _state;
  @override
  S get state => _state;
  void emit(S state) => _state = state;
}

extension ReadContext on BuildContext {
  T read<T>() => throw UnimplementedError();
}

extension WatchContext on BuildContext {
  T watch<T>() => throw UnimplementedError();
}

extension SelectContext on BuildContext {
  R select<T, R>(R Function(T value) selector) => throw UnimplementedError();
}

typedef BlocWidgetBuilder<S> = Widget Function(BuildContext context, S state);

class BlocBuilder<B extends BlocBase<S>, S> extends Widget {
  final BlocWidgetBuilder<S> builder;
  const BlocBuilder({super.key, required this.builder});
}
''';
