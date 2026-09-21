## 0.1.8

- The flutterbloc rules match only calls on flutterbloc_kit's `ReadContext`,
  `WatchContext` and `SelectContext` extensions. 0.1.6 matched any `watch` or
  `select` declared in that package, so flutterbloc_kit's own `StreamWatch`
  and DartNative's `Listenable.watch` were flagged.
- The flutterbloc rules skip `test/` directories, where a `watch` on a fake
  context is the point of the test.

## 0.1.6

- Rules for [flutterbloc_kit](https://dartpub.dev/packages/flutterbloc_kit):
  `flutterbloc_watch_outside_build` and `flutterbloc_read_state_in_build`
  (warnings, on by default) catch `context.watch` / `context.select` in an
  event handler, `initState` or a helper, and `context.read<T>().state`
  rendered in build; neither ever rebuilds. `flutterbloc_read_in_build`
  (opt-in lint) flags every `context.read` in build, provider's own guidance.
  A closure with a `BuildContext` parameter counts as a build, so
  `Builder` and `BlocBuilder` callbacks stay quiet.

## 0.1.5

- Removed `dartnative_mirror_text_controller` and its quick fix. Framework
  revision 80edbf105e made `TextEditingController` two-way, so the warning was
  wrong. (Meant for 0.1.1; the published 0.1.4 still carried it.)

## 0.1.1

- Removed `dartnative_mirror_text_controller` and its fix: since framework
  revision 80edbf105e the controller is two-way, so the warning was wrong.
- `dartnative_fab_slot_android_only` stays quiet when the argument is gated on
  `Platform.isAndroid`, `Platform.isIOS` or `isIOS26`.
- Wrap assists accept any expression of a widget type, not only constructor
  calls, and a selection across several `children:` siblings wraps them
  together in one Column, Row or Stack, as in Flutter.
- `const` handling matches the Flutter assists: an explicit `const` stays on
  the wrapped widget, `EdgeInsets` gets no redundant `const` inside a const
  context, and a multi-line child is laid out on its own lines. Beyond
  Flutter: wrapping with Builder or an async builder inside a const context
  drops the enclosing `const` instead of producing invalid code, and removing
  a `const` wrapper keeps its child `const`.
- Convert to children: / child: are only offered when the widget's constructor
  actually has that parameter.
- With the cursor on an argument label (`child:`, `floatingActionButton:`),
  assists target the argument's widget instead of the enclosing one.

## 0.1.0

Initial release as `assists_kit` (previously published as `dartnative_assists`).

Assists on a DartNative widget creation:

- Wrap with Center, Container, Padding, SizedBox, Expanded, Flexible,
  SafeArea, GestureDetector, GlassEffectContainer, Column, Row, Stack,
  Builder, FutureBuilder, StreamBuilder, ValueListenableBuilder, or a widget
  name you type.
- Remove this widget, Swap with child, Swap with parent.
- Convert to children: / Convert to child:.
- Move widget up / down inside a `children:` list.

Assists on a class header:

- Convert to StatefulWidget, Convert to StatelessWidget.

Warning rules, on by default:

- `dartnative_fab_slot_android_only`
- `dartnative_menu_action_must_be_alone`
- `dartnative_uniform_border_only`
- `dartnative_custom_paint_finite_size`
- `dartnative_positioned_must_be_outermost`
- `dartnative_snackbar_action_not_wired`

Lint rules, opt-in:

- `dartnative_offstage_loses_state`
