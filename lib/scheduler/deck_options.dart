/// Configurable options for deck study parameters.
class DeckOptions {
  // Learning phase
  final List<int> learnSteps; // in minutes
  final int graduatingInterval; // days
  final int easyInterval; // days

  // Review phase
  final int startingEase; // * 1000 (e.g. 2500 = 250%)
  final double easyBonus; // multiplier (e.g. 1.3)
  final double hardMultiplier; // multiplier for hard interval (e.g. 1.2)
  final int intervalModifier; // percentage (100 = no change)
  final int maxInterval; // days

  // Lapse phase
  final List<int> relearningSteps; // in minutes
  final double newIntervalMultiplier; // % of old interval on lapse (e.g. 0.0 = 0%)
  final int minInterval; // minimum interval after lapse

  // Limits
  final int maxNewPerDay;
  final int maxReviewsPerDay;

  const DeckOptions({
    this.learnSteps = const [1, 10],
    this.graduatingInterval = 1,
    this.easyInterval = 4,
    this.startingEase = 2500,
    this.easyBonus = 1.3,
    this.hardMultiplier = 1.2,
    this.intervalModifier = 100,
    this.maxInterval = 36500,
    this.relearningSteps = const [10],
    this.newIntervalMultiplier = 0.0,
    this.minInterval = 1,
    this.maxNewPerDay = 20,
    this.maxReviewsPerDay = 9999,
  });

  Map<String, dynamic> toMap() => {
    'learnSteps': learnSteps,
    'graduatingInterval': graduatingInterval,
    'easyInterval': easyInterval,
    'startingEase': startingEase,
    'easyBonus': easyBonus,
    'hardMultiplier': hardMultiplier,
    'intervalModifier': intervalModifier,
    'maxInterval': maxInterval,
    'relearningSteps': relearningSteps,
    'newIntervalMultiplier': newIntervalMultiplier,
    'minInterval': minInterval,
    'maxNewPerDay': maxNewPerDay,
    'maxReviewsPerDay': maxReviewsPerDay,
  };

  factory DeckOptions.fromMap(Map<String, dynamic> map) {
    return DeckOptions(
      learnSteps: (map['learnSteps'] as List?)?.cast<int>() ?? const [1, 10],
      graduatingInterval: map['graduatingInterval'] as int? ?? 1,
      easyInterval: map['easyInterval'] as int? ?? 4,
      startingEase: map['startingEase'] as int? ?? 2500,
      easyBonus: (map['easyBonus'] as num?)?.toDouble() ?? 1.3,
      hardMultiplier: (map['hardMultiplier'] as num?)?.toDouble() ?? 1.2,
      intervalModifier: map['intervalModifier'] as int? ?? 100,
      maxInterval: map['maxInterval'] as int? ?? 36500,
      relearningSteps: (map['relearningSteps'] as List?)?.cast<int>() ?? const [10],
      newIntervalMultiplier: (map['newIntervalMultiplier'] as num?)?.toDouble() ?? 0.0,
      minInterval: map['minInterval'] as int? ?? 1,
      maxNewPerDay: map['maxNewPerDay'] as int? ?? 20,
      maxReviewsPerDay: map['maxReviewsPerDay'] as int? ?? 9999,
    );
  }

  DeckOptions copyWith({
    List<int>? learnSteps,
    int? graduatingInterval,
    int? easyInterval,
    int? startingEase,
    double? easyBonus,
    double? hardMultiplier,
    int? intervalModifier,
    int? maxInterval,
    List<int>? relearningSteps,
    double? newIntervalMultiplier,
    int? minInterval,
    int? maxNewPerDay,
    int? maxReviewsPerDay,
  }) {
    return DeckOptions(
      learnSteps: learnSteps ?? this.learnSteps,
      graduatingInterval: graduatingInterval ?? this.graduatingInterval,
      easyInterval: easyInterval ?? this.easyInterval,
      startingEase: startingEase ?? this.startingEase,
      easyBonus: easyBonus ?? this.easyBonus,
      hardMultiplier: hardMultiplier ?? this.hardMultiplier,
      intervalModifier: intervalModifier ?? this.intervalModifier,
      maxInterval: maxInterval ?? this.maxInterval,
      relearningSteps: relearningSteps ?? this.relearningSteps,
      newIntervalMultiplier: newIntervalMultiplier ?? this.newIntervalMultiplier,
      minInterval: minInterval ?? this.minInterval,
      maxNewPerDay: maxNewPerDay ?? this.maxNewPerDay,
      maxReviewsPerDay: maxReviewsPerDay ?? this.maxReviewsPerDay,
    );
  }
}
