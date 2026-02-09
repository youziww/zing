import '../models/card.dart';

/// Ease ratings for answering cards.
class Ease {
  static const int again = 1;
  static const int hard = 2;
  static const int good = 3;
  static const int easy = 4;
}

/// Represents the scheduling result after answering a card.
class ScheduleResult {
  final int type;
  final int queue;
  final int due;
  final int interval;
  final int easeFactor;
  final int reps;
  final int lapses;
  final int left;

  ScheduleResult({
    required this.type,
    required this.queue,
    required this.due,
    required this.interval,
    required this.easeFactor,
    required this.reps,
    required this.lapses,
    required this.left,
  });

  /// Apply this result to a card, returning a new card.
  ReviewCard applyTo(ReviewCard card) {
    return card.copyWith(
      type: type,
      queue: queue,
      due: due,
      interval: interval,
      easeFactor: easeFactor,
      reps: reps,
      lapses: lapses,
      left: left,
      mod: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }
}

/// Human-readable description of next review time.
String describeNextReview(int intervalOrDue, bool isLearning) {
  if (isLearning) {
    // Due is a timestamp in seconds
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = intervalOrDue - now;
    if (diff < 60) return '< 1 min';
    if (diff < 3600) return '${diff ~/ 60} min';
    if (diff < 86400) return '${diff ~/ 3600} h';
    return '${diff ~/ 86400} d';
  } else {
    // Interval in days
    if (intervalOrDue == 0) return '< 1 min';
    if (intervalOrDue == 1) return '1 d';
    if (intervalOrDue < 30) return '$intervalOrDue d';
    if (intervalOrDue < 365) return '${(intervalOrDue / 30).toStringAsFixed(1)} mo';
    return '${(intervalOrDue / 365).toStringAsFixed(1)} yr';
  }
}
