# assists_kit

Option+Enter widget assists and DartNative-specific warnings for
[DartNative](https://dartnative.com) projects. Runs inside the Dart Analysis
Server, so it works the same in Android Studio, IntelliJ and VS Code.

## Why

The analysis server ships "Wrap with Container", "Convert to StatefulWidget"
and the rest of the Flutter assists, but each one checks that the widget
class comes from `package:flutter/src/widgets/framework.dart`. DartNative's
`Widget` lives in `package:dartnative`, so in a DartNative file those assists
never appear. This plugin re-implements them against DartNative's types.

It also turns the DartNative behaviours that fail silently or crash at mount
into analyzer warnings, so they are caught while typing instead of on a
device.

## Setup

The package is published on dartpub.dev, DartNative's registry. The analysis
server resolves plugins with plain `dart pub`, which only knows pub.dev, so
the `hosted` line is required. In the `analysis_options.yaml` at the root of
your project:

```yaml
plugins:
  assists_kit:
    hosted: https://dartpub.dev
    version: ^0.1.8
```

Restart the Dart Analysis Server once (Android Studio: Tools › Dart › Restart
Dart Analysis Server; VS Code: "Dart: Restart Analysis Server"). The first
restart after enabling builds the plugin isolate and takes a few seconds.

Requires Dart 3.11 or later; the DartNative `dn` toolchain ships a newer SDK.

## Assists

With the cursor on a widget (a constructor call, or any expression of a
widget type such as a `child` parameter):

| Assist | Result |
|---|---|
| Wrap with Center / Container / SizedBox / Expanded / Flexible / SafeArea / GestureDetector / GlassEffectContainer | `Name(child: …)` |
| Wrap with Padding | `Padding(padding: const EdgeInsets.all(8.0), child: …)` |
| Wrap with Column / Row / Stack | multi-line `children: [ … ]`; with a selection spanning several siblings in a `children:` list, wraps them together |
| Wrap with Builder | `Builder(builder: (context) => …)` |
| Wrap with FutureBuilder / StreamBuilder / ValueListenableBuilder | `…builder: (context, snapshot) => …` |
| Wrap with widget… | a wrapper name you type |
| Remove this widget | replaces a wrapper with its single child |
| Swap with child / Swap with parent | exchanges two single-`child:` widgets, keeping their other arguments |
| Convert to children: / Convert to child: | switches between the two slots |
| Move widget up / down | reorders inside a `children:` list |

With the cursor on a class header line:

| Assist | Result |
|---|---|
| Convert to StatefulWidget | constructors and final fields stay on the widget; other members move to `_XState`; field references become `widget.x`, statics become `X.y`, `$x` interpolations become `${widget.x}` |
| Convert to StatelessWidget | merges the State back; offered only when the State has no lifecycle overrides, mixins, or `setState` calls |

## Warnings (on by default)

| Rule | What it catches |
|---|---|
| `dartnative_fab_slot_android_only` | `Scaffold.floatingActionButton`, which renders on Android and shows nothing on iOS |
| `dartnative_menu_action_must_be_alone` | a `BarButtonItem` with `menu:` beside other actions, which asserts at mount |
| `dartnative_uniform_border_only` | per-side `Border(...)`, which DartNative ignores in favour of `top` |
| `dartnative_custom_paint_finite_size` | `CustomPaint(size: Size(double.infinity, …))`, which paints off-screen |
| `dartnative_positioned_must_be_outermost` | a wrapper above `Positioned` in a `Stack`, which is dropped |
| `dartnative_snackbar_action_not_wired` | `SnackBarAction.onPressed`, which never fires |
| `flutterbloc_watch_outside_build` | `context.watch` / `context.select` (flutterbloc_kit) in an event handler, `initState` or a helper, which read once and never rebuild |
| `flutterbloc_read_state_in_build` | `context.read<T>().state` rendered in build, which goes stale on the first emit |

Opt-in lint:

| Rule | What it catches |
|---|---|
| `dartnative_offstage_loses_state` | `Offstage`, which unmounts its child in DartNative |
| `flutterbloc_read_in_build` | any `context.read` in build; provider's guidance is read in handlers, watch in build |

Enable it under the plugin entry:

```yaml
plugins:
  assists_kit:
    hosted: https://dartpub.dev
    version: ^0.1.1
    diagnostics:
      dartnative_offstage_loses_state: true
```

Suppress any rule on a line with `// ignore: assists_kit/<rule>`.

## Development

```sh
dart pub get
dart test          # resolves against a stub package:dartnative, no SDK needed
dart analyze
```

`tool/try_assists.dart` runs the assists against a real file inside a
DartNative project:

```sh
dart run tool/try_assists.dart path/to/app/lib/main.dart --find "Text(" --apply 1
```

The `analysis_server_plugin` and `analyzer` dependencies move in lockstep
with the Dart SDK. After a `dn upgrade`, run `dart pub upgrade` and the tests.

When the plugin is enabled from a local `path:` and you change its source,
the analysis server keeps running the isolate it already compiled. Delete
`~/.dartServer/.plugin_manager` and restart the server to pick up the change.
An "error occurred while executing an analyzer plugin" line during
`dn analyze` after an edit is that stale isolate, not a bug in the change.

## Sources of the rules

Each warning encodes one fact from the DartNative widget reference or from
on-device testing on DartNative 1.0.0 (September 2026). The rule's
`description` names which. When DartNative changes a behaviour the rule is
retired: the controller-mirror rule was removed the day framework revision
80edbf105e made `TextEditingController` two-way.
