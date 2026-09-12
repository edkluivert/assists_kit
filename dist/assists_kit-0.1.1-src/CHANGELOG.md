## 0.1.1

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
- `dartnative_mirror_text_controller` (with a quick fix)
- `dartnative_custom_paint_finite_size`
- `dartnative_positioned_must_be_outermost`
- `dartnative_snackbar_action_not_wired`

Lint rules, opt-in:

- `dartnative_offstage_loses_state`
