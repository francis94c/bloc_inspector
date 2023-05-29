# bloc_inspector

This package allows you listen for changes in your bloc. Use together with BLoC Inspector desktop application.

## Features

- Listen for changes in your BLoCs.

## Getting started

Put your `runApp` method in a `BlocOverrides` zone.

```dart
BlocOverrides.runZoned(
    () async {
        runApp(MyApp());
    },
    blocObserver: InvestigativeBlocObserver(
        FlutterBlocInvestigativeClient(
            inEmulator: true,
            enabled: kDebugMode,
        ),
    ),
);
```
