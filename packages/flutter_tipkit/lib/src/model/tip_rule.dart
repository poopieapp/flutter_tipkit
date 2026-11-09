import 'package:flutter/foundation.dart';
import 'package:flutter_tipkit/src/datastore/tip_datastore.dart';
import 'package:flutter_tipkit/src/model/tip.dart';
import 'package:flutter_tipkit/src/model/tip_event.dart';
import 'package:flutter_tipkit/src/model/tip_parameter.dart';

/// What a [TipRule] can look at when it is evaluated.
abstract interface class TipRuleContext {
  /// The time the rules are evaluated at.
  DateTime get now;

  /// The current value of [parameter].
  T parameterValue<T>(TipParameter<T> parameter);

  /// The donations of [event] so far.
  TipEventDonations donations(TipEvent event);

  /// What is stored about the tip with [tipId], if anything.
  TipRecord? record(String tipId);
}

/// A condition for a tip to become available.
///
/// Rules are evaluated synchronously against the current state, so anything
/// outside the tip system that a rule depends on is passed in through a
/// [TipParameter] or counted with a [TipEvent].
///
/// Implement this class for conditions the built-in rules cannot express.
@immutable
abstract class TipRule {
  /// Lets subclasses be `const`.
  const TipRule();

  /// Holds while [predicate] returns true for the value of [parameter].
  static TipRule parameter<T>(
    TipParameter<T> parameter,
    bool Function(T value) predicate,
  ) {
    return _ParameterRule<T>(parameter, predicate);
  }

  /// Holds while [predicate] returns true for the donations of [event].
  static TipRule event(
    TipEvent event,
    bool Function(TipEventDonations donations) predicate,
  ) {
    return _EventRule(event, predicate);
  }

  /// Holds once [tip] has been invalidated, at least [minAge] ago, and, if
  /// [reasons] is given, for one of those reasons.
  ///
  /// Use it to show one tip only after another, at a different place in the
  /// app. For tips shown one after another at the same place, a `TipGroup`
  /// is simpler.
  static TipRule tipInvalidated(
    Tip tip, {
    Duration minAge = Duration.zero,
    Set<TipInvalidationReason>? reasons,
  }) {
    return _TipInvalidatedRule(tip.id, minAge, reasons);
  }

  /// Holds when every rule in [rules] holds.
  static TipRule allOf(List<TipRule> rules) => _AllOfRule(rules);

  /// Holds when at least one rule in [rules] holds.
  static TipRule anyOf(List<TipRule> rules) => _AnyOfRule(rules);

  /// Holds when [rule] does not.
  static TipRule not(TipRule rule) => _NotRule(rule);

  /// Whether the rule holds in [context].
  bool evaluate(TipRuleContext context);

  /// The earliest time after `context.now` at which the result of [evaluate]
  /// can change by itself, without any parameter, event or tip changing.
  ///
  /// Time-based rules return it so the engine re-evaluates the tips at that
  /// time. Null, the default, means the result changes only with the state.
  DateTime? nextChange(TipRuleContext context) => null;
}

final class _ParameterRule<T> extends TipRule {
  const _ParameterRule(this.parameter, this.predicate);

  final TipParameter<T> parameter;
  final bool Function(T value) predicate;

  @override
  bool evaluate(TipRuleContext context) {
    return predicate(context.parameterValue(parameter));
  }
}

final class _EventRule extends TipRule {
  const _EventRule(this.event, this.predicate);

  final TipEvent event;
  final bool Function(TipEventDonations donations) predicate;

  @override
  bool evaluate(TipRuleContext context) {
    return predicate(context.donations(event));
  }
}

final class _TipInvalidatedRule extends TipRule {
  const _TipInvalidatedRule(this.tipId, this.minAge, this.reasons);

  final String tipId;
  final Duration minAge;
  final Set<TipInvalidationReason>? reasons;

  DateTime? _readyAt(TipRuleContext context) {
    final record = context.record(tipId);
    final reason = record?.invalidationReason;
    if (record == null || reason == null) return null;
    if (reasons != null && !reasons!.contains(reason)) return null;
    // A record without a time counts as long ago.
    final invalidatedAt = record.invalidatedAt;
    if (invalidatedAt == null) return DateTime.utc(0);
    return invalidatedAt.add(minAge);
  }

  @override
  bool evaluate(TipRuleContext context) {
    final readyAt = _readyAt(context);
    return readyAt != null && !readyAt.isAfter(context.now);
  }

  @override
  DateTime? nextChange(TipRuleContext context) {
    final readyAt = _readyAt(context);
    return readyAt != null && readyAt.isAfter(context.now) ? readyAt : null;
  }
}

final class _AllOfRule extends TipRule {
  const _AllOfRule(this.rules);

  final List<TipRule> rules;

  @override
  bool evaluate(TipRuleContext context) {
    return rules.every((rule) => rule.evaluate(context));
  }

  @override
  DateTime? nextChange(TipRuleContext context) => _earliest(rules, context);
}

final class _AnyOfRule extends TipRule {
  const _AnyOfRule(this.rules);

  final List<TipRule> rules;

  @override
  bool evaluate(TipRuleContext context) {
    return rules.any((rule) => rule.evaluate(context));
  }

  @override
  DateTime? nextChange(TipRuleContext context) => _earliest(rules, context);
}

final class _NotRule extends TipRule {
  const _NotRule(this.rule);

  final TipRule rule;

  @override
  bool evaluate(TipRuleContext context) => !rule.evaluate(context);

  @override
  DateTime? nextChange(TipRuleContext context) => rule.nextChange(context);
}

/// The earliest [TipRule.nextChange] of [rules], if any.
DateTime? earliestNextChange(Iterable<TipRule> rules, TipRuleContext context) {
  return _earliest(rules, context);
}

DateTime? _earliest(Iterable<TipRule> rules, TipRuleContext context) {
  DateTime? earliest;
  for (final rule in rules) {
    final next = rule.nextChange(context);
    if (next != null && (earliest == null || next.isBefore(earliest))) {
      earliest = next;
    }
  }
  return earliest;
}
