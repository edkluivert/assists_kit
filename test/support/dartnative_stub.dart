/// A minimal stand-in for `package:dartnative` so tests resolve DartNative
/// types without the real SDK. Only the declarations the assists and rules
/// look at are present; bodies are irrelevant.
library;

const dartnativeStub = r'''
library dartnative;

typedef VoidCallback = void Function();
typedef ValueChanged<T> = void Function(T value);
typedef WidgetBuilder = Widget Function(BuildContext context);

class Key {
  const Key();
}

class BuildContext {}

abstract class Widget {
  final Key? key;
  const Widget({this.key});
}

abstract class StatelessWidget extends Widget {
  const StatelessWidget({super.key});
  Widget build(BuildContext context);
}

abstract class StatefulWidget extends Widget {
  const StatefulWidget({super.key});
  State<StatefulWidget> createState();
}

abstract class State<T extends StatefulWidget> {
  late T widget;
  late BuildContext context;
  bool get mounted => true;
  void initState() {}
  void dispose() {}
  void setState(VoidCallback fn) {}
  Widget build(BuildContext context);
}

class Color {
  final int value;
  const Color(this.value);
}

class Colors {
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);
  static const red = Color(0xFFFF0000);
}

class TextStyle {
  final double? fontSize;
  final Color? color;
  const TextStyle({this.fontSize, this.color});
}

class EdgeInsets {
  final double value;
  const EdgeInsets.all(this.value);
}

class Size {
  final double width;
  final double height;
  const Size(this.width, this.height);
}

class BorderSide {
  final Color? color;
  final double width;
  const BorderSide({this.color, this.width = 1});
  static const none = BorderSide(width: 0);
}

class Border {
  final BorderSide top;
  final BorderSide right;
  final BorderSide bottom;
  final BorderSide left;
  const Border({
    this.top = BorderSide.none,
    this.right = BorderSide.none,
    this.bottom = BorderSide.none,
    this.left = BorderSide.none,
  });
  const Border.all({Color? color, double width = 1})
      : this(
          top: BorderSide(color: color, width: width),
          right: BorderSide(color: color, width: width),
          bottom: BorderSide(color: color, width: width),
          left: BorderSide(color: color, width: width),
        );
}

class BoxDecoration {
  final Color? color;
  final Border? border;
  const BoxDecoration({this.color, this.border});
}

class IconData {
  final int codePoint;
  const IconData(this.codePoint);
}

class CupertinoIcons {
  static const plus = IconData(1);
  static const trash = IconData(2);
}

class Text extends Widget {
  final String data;
  final TextStyle? style;
  const Text(this.data, {super.key, this.style});
}

class Icon extends Widget {
  final IconData icon;
  const Icon(this.icon, {super.key});
}

class Container extends Widget {
  final Widget? child;
  final EdgeInsets? padding;
  final BoxDecoration? decoration;
  final Color? color;
  final double? width;
  final double? height;
  const Container({
    super.key,
    this.child,
    this.padding,
    this.decoration,
    this.color,
    this.width,
    this.height,
  });
}

class Center extends Widget {
  final Widget? child;
  const Center({super.key, this.child});
}

class Padding extends Widget {
  final EdgeInsets padding;
  final Widget? child;
  const Padding({super.key, required this.padding, this.child});
}

class SizedBox extends Widget {
  final double? width;
  final double? height;
  final Widget? child;
  const SizedBox({super.key, this.width, this.height, this.child});
}

class Column extends Widget {
  final List<Widget> children;
  const Column({super.key, this.children = const []});
}

class Row extends Widget {
  final List<Widget> children;
  const Row({super.key, this.children = const []});
}

class Stack extends Widget {
  final List<Widget> children;
  const Stack({super.key, this.children = const []});
}

class IndexedStack extends Widget {
  final int index;
  final List<Widget> children;
  const IndexedStack({super.key, required this.index, required this.children});
}

class Positioned extends Widget {
  final double? left;
  final double? top;
  final double? right;
  final double? bottom;
  final Widget child;
  const Positioned({
    super.key,
    this.left,
    this.top,
    this.right,
    this.bottom,
    required this.child,
  });
}

/// Accepts both slots, for the child/children conversion tests.
class Wrapper extends Widget {
  final Widget? child;
  final List<Widget>? children;
  const Wrapper({super.key, this.child, this.children});
}

class Offstage extends Widget {
  final bool offstage;
  final Widget? child;
  const Offstage({super.key, this.offstage = true, this.child});
}

class GestureDetector extends Widget {
  final Widget? child;
  final VoidCallback? onTap;
  const GestureDetector({super.key, this.child, this.onTap});
}

class Scaffold extends Widget {
  final Widget? body;
  final Widget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? bottomInputBar;
  final Widget? bottomAccessory;
  final Color? backgroundColor;
  const Scaffold({
    super.key,
    this.body,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.bottomInputBar,
    this.bottomAccessory,
    this.backgroundColor,
  });
}

class AppBar extends Widget {
  final Widget? title;
  final List<Widget>? actions;
  const AppBar({super.key, this.title, this.actions});
}

class MenuAction {
  final String title;
  final VoidCallback onTap;
  const MenuAction({required this.title, required this.onTap});
}

class BarButtonItem extends Widget {
  final String? title;
  final String? icon;
  final VoidCallback? onPressed;
  final List<MenuAction>? menu;
  const BarButtonItem({
    super.key,
    this.title,
    this.icon,
    this.onPressed,
    this.menu,
  });
}

class FloatingActionButton extends Widget {
  final Widget child;
  final VoidCallback? onPressed;
  const FloatingActionButton({super.key, required this.child, this.onPressed});
}

class TextEditingController {
  String text = '';
  void clear() {}
}

class TextField extends Widget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  const TextField({super.key, this.controller, this.onChanged});
}

class CustomPainter {}

class CustomPaint extends Widget {
  final Size? size;
  final CustomPainter? painter;
  const CustomPaint({super.key, this.size, this.painter});
}

class SnackBarAction {
  final String label;
  final VoidCallback onPressed;
  const SnackBarAction({required this.label, required this.onPressed});
}
''';
