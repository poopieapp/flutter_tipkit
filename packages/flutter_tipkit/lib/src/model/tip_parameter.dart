import 'package:flutter/foundation.dart';
import 'package:flutter_tipkit/src/engine/tips.dart';

/// A persisted value that tip rules can depend on.
///
/// ```dart
/// const isLoggedIn = TipParameter<bool>('isLoggedIn', false);
///
/// // When the value changes:
/// isLoggedIn.value = true;
///
/// // In a tip:
/// @override
/// List<TipRule> get rules => [TipRule.parameter(isLoggedIn, (v) => v)];
/// ```
///
/// Values are stored with the configured `TipDatastore`. Values the datastore
/// cannot store as they are (anything other than `bool`, `int`, `double`,
/// `String`, `null`, and lists and maps of those) need [encode] and [decode].
@immutable
class TipParameter<T> {
  /// Creates a parameter stored under [id], [defaultValue] until it is set.
  const TipParameter(this.id, this.defaultValue, {this.encode, this.decode});

  /// The stable identifier the value is stored under.
  final String id;

  /// The value before anything is set.
  final T defaultValue;

  /// Turns a value into something the datastore can store.
  final Object? Function(T value)? encode;

  /// Turns a stored value back into a [T].
  final T Function(Object? stored)? decode;

  /// The current value.
  T get value => Tips.center.parameterValue(this);

  /// Stores [newValue] and re-evaluates the tips.
  set value(T newValue) => Tips.center.setParameterValue(this, newValue);

  /// Converts [stored] to a [T], falling back to the [defaultValue].
  T decodeStored(Object? stored) {
    final decode = this.decode;
    if (decode != null) return decode(stored);
    return stored is T ? stored : defaultValue;
  }

  /// Converts [value] to something the datastore can store.
  Object? encodeValue(T value) => encode?.call(value) ?? value;

  @override
  bool operator ==(Object other) => other is TipParameter && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'TipParameter($id)';
}
