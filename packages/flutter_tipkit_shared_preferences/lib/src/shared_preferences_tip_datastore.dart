import 'dart:async';
import 'dart:convert';

import 'package:flutter_tipkit/flutter_tipkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A [TipDatastore] that keeps tip state in shared preferences, so it
/// survives app restarts.
///
/// Every record is one JSON string under a key starting with [keyPrefix]:
/// `tipkit.tip.<id>`, `tipkit.parameter.<id>`, `tipkit.event.<id>` and
/// `tipkit.global` by default. [clear] removes only those keys.
///
/// ```dart
/// await Tips.configure(
///   datastore: SharedPreferencesTipDatastore.async(SharedPreferencesAsync()),
/// );
/// ```
class SharedPreferencesTipDatastore implements TipDatastore {
  /// Stores tips with the cached [SharedPreferences] API.
  SharedPreferencesTipDatastore(
    SharedPreferences preferences, {
    this.keyPrefix = 'tipkit.',
  }) : _store = _CachedStore(preferences);

  /// Stores tips with the [SharedPreferencesAsync] API.
  SharedPreferencesTipDatastore.async(
    SharedPreferencesAsync preferences, {
    this.keyPrefix = 'tipkit.',
  }) : _store = _AsyncStore(preferences);

  /// The start of every key this datastore writes.
  final String keyPrefix;

  final _Store _store;

  String get _tipPrefix => '${keyPrefix}tip.';
  String get _parameterPrefix => '${keyPrefix}parameter.';
  String get _eventPrefix => '${keyPrefix}event.';
  String get _globalKey => '${keyPrefix}global';

  @override
  Future<TipStoreSnapshot> load() async {
    final keys = (await _store.keys())
        .where((key) => key.startsWith(keyPrefix))
        .toList();
    final tips = <String, TipRecord>{};
    final parameters = <String, Object?>{};
    final events = <String, List<DateTime>>{};
    var global = const TipGlobalRecord();

    for (final key in keys) {
      final json = _decode(await _store.getString(key));
      if (json == _invalid) continue;
      if (key == _globalKey && json is Map<String, Object?>) {
        global = TipGlobalRecord.fromJson(json);
      } else if (key.startsWith(_tipPrefix) && json is Map<String, Object?>) {
        tips[key.substring(_tipPrefix.length)] = TipRecord.fromJson(json);
      } else if (key.startsWith(_parameterPrefix) &&
          json is Map<String, Object?>) {
        parameters[key.substring(_parameterPrefix.length)] = json['value'];
      } else if (key.startsWith(_eventPrefix) && json is List<Object?>) {
        events[key.substring(_eventPrefix.length)] = [
          for (final millis in json.whereType<num>())
            DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true),
        ];
      }
    }
    return TipStoreSnapshot(
      tips: tips,
      parameters: parameters,
      events: events,
      global: global,
    );
  }

  @override
  Future<void> writeTip(String tipId, TipRecord? record) {
    final key = '$_tipPrefix$tipId';
    if (record == null) return _store.remove(key);
    return _store.setString(key, jsonEncode(record.toJson()));
  }

  @override
  Future<void> writeParameter(String parameterId, Object? value) {
    return _store.setString(
      '$_parameterPrefix$parameterId',
      jsonEncode({'value': value}),
    );
  }

  @override
  Future<void> writeEvent(String eventId, List<DateTime> donations) {
    return _store.setString(
      '$_eventPrefix$eventId',
      jsonEncode([for (final date in donations) date.millisecondsSinceEpoch]),
    );
  }

  @override
  Future<void> writeGlobal(TipGlobalRecord record) {
    return _store.setString(_globalKey, jsonEncode(record.toJson()));
  }

  @override
  Future<void> clear() async {
    final keys = (await _store.keys()).where(
      (key) => key.startsWith(keyPrefix),
    );
    for (final key in keys.toList()) {
      await _store.remove(key);
    }
  }
}

const Object _invalid = Object();

/// The decoded JSON in [value], or [_invalid] when there is none or it is
/// not valid JSON. A corrupt entry is skipped rather than failing the load.
Object? _decode(String? value) {
  if (value == null) return _invalid;
  try {
    return jsonDecode(value);
  } on FormatException {
    return _invalid;
  }
}

/// The few operations the datastore needs from either shared preferences API.
abstract interface class _Store {
  Future<Set<String>> keys();
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

class _CachedStore implements _Store {
  _CachedStore(this.preferences);

  final SharedPreferences preferences;

  @override
  Future<Set<String>> keys() async => preferences.getKeys();

  @override
  Future<String?> getString(String key) async {
    final value = preferences.get(key);
    return value is String ? value : null;
  }

  @override
  Future<void> setString(String key, String value) async {
    await preferences.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await preferences.remove(key);
  }
}

class _AsyncStore implements _Store {
  _AsyncStore(this.preferences);

  final SharedPreferencesAsync preferences;

  @override
  Future<Set<String>> keys() => preferences.getKeys();

  @override
  Future<String?> getString(String key) => preferences.getString(key);

  @override
  Future<void> setString(String key, String value) {
    return preferences.setString(key, value);
  }

  @override
  Future<void> remove(String key) => preferences.remove(key);
}
