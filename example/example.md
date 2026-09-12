# Using assists_kit

Add the plugin to the `analysis_options.yaml` at the root of your DartNative
project. `plugins` is a top-level key, not nested under `analyzer`.

```yaml
plugins:
  assists_kit:
    hosted: https://dartpub.dev
    version: ^0.1.1
```

Restart the Dart Analysis Server (Android Studio: Tools › Dart › Restart Dart
Analysis Server; VS Code: "Dart: Restart Analysis Server"). Then, with the
cursor on any widget:

```dart
Scaffold(
  body: Center(
    child: Text('hello'),   // Option+Enter here: Wrap with Column, Remove this widget, …
  ),
)
```

And on a class line:

```dart
class Counter extends StatelessWidget {   // Option+Enter: Convert to StatefulWidget
  final int start;
  const Counter({super.key, this.start = 0});

  @override
  Widget build(BuildContext context) => Text('$start');
}
```

The warning rules run in the IDE and in `dn analyze`. To enable the opt-in
lint as well:

```yaml
plugins:
  assists_kit:
    hosted: https://dartpub.dev
    version: ^0.1.1
    diagnostics:
      dartnative_offstage_loses_state: true
```
