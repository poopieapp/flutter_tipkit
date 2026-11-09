# flutter_tipkit_shared_preferences

A [shared_preferences](https://pub.dev/packages/shared_preferences) datastore
for [flutter_tipkit](https://pub.dev/packages/flutter_tipkit), so tip state survives app restarts.

```dart
await Tips.configure(
  datastore: SharedPreferencesTipDatastore.async(SharedPreferencesAsync()),
);

// Or, with the cached API:
final preferences = await SharedPreferences.getInstance();
await Tips.configure(datastore: SharedPreferencesTipDatastore(preferences));
```

Each tip, parameter and event is one JSON string under a key starting with
`tipkit.` (change it with `keyPrefix`). `Tips.resetDatastore()` removes only
those keys. Entries that cannot be read are skipped.
