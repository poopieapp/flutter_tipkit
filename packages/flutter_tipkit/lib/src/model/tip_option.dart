import 'package:flutter/foundation.dart';

/// An option that changes how a tip is displayed.
@immutable
sealed class TipOption {
  const TipOption();

  /// Invalidates the tip, with `TipInvalidationReason.displayCountExceeded`,
  /// once it has been displayed [count] times.
  const factory TipOption.maxDisplayCount(int count) = MaxDisplayCountOption;

  /// Lets the tip show regardless of the configured `TipDisplayFrequency`.
  const factory TipOption.ignoresDisplayFrequency() =
      IgnoresDisplayFrequencyOption;
}

/// See [TipOption.maxDisplayCount].
final class MaxDisplayCountOption extends TipOption {
  /// Creates the option.
  const MaxDisplayCountOption(this.count) : assert(count > 0, 'count > 0');

  /// How many times the tip may be displayed.
  final int count;
}

/// See [TipOption.ignoresDisplayFrequency].
final class IgnoresDisplayFrequencyOption extends TipOption {
  /// Creates the option.
  const IgnoresDisplayFrequencyOption();
}
