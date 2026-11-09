/// How often a tip that has never been displayed may appear.
///
/// After a tip is displayed for the first time, no other new tip appears
/// until [interval] has passed. Tips that were displayed before, and tips
/// with `TipOption.ignoresDisplayFrequency`, are not held back.
enum TipDisplayFrequency {
  /// New tips appear as soon as they are available.
  immediate(Duration.zero),

  /// At most one new tip per hour.
  hourly(Duration(hours: 1)),

  /// At most one new tip per day.
  daily(Duration(days: 1)),

  /// At most one new tip per week.
  weekly(Duration(days: 7)),

  /// At most one new tip per 30 days.
  monthly(Duration(days: 30));

  const TipDisplayFrequency(this.interval);

  /// The minimum time between two new tips.
  final Duration interval;
}
