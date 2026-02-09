import 'dart:math';
import '../models/card.dart';
import 'card_state.dart';
import 'deck_options.dart';

/// SM-2 based scheduler compatible with Anki's algorithm.
class Scheduler {
  final int today; // day number since collection creation
  final int dayCutoff; // timestamp (seconds) for start of today

  Scheduler({required this.today, required this.dayCutoff});

  /// Answer a card with the given ease (1-4) and return the scheduling result.
  ScheduleResult answerCard(ReviewCard card, int ease, DeckOptions options) {
    if (card.queue == CardQueue.newQueue || card.queue == CardQueue.learning) {
      return _answerLearningCard(card, ease, options);
    } else if (card.queue == CardQueue.review) {
      return _answerReviewCard(card, ease, options);
    } else if (card.queue == CardQueue.relearning) {
      return _answerRelearningCard(card, ease, options);
    }
    throw ArgumentError('Cannot answer card in queue ${card.queue}');
  }

  /// Get the next review times for each ease level (for button labels).
  Map<int, String> getNextReviewTimes(ReviewCard card, DeckOptions options) {
    final result = <int, String>{};
    for (final ease in [Ease.again, Ease.hard, Ease.good, Ease.easy]) {
      try {
        final sr = answerCard(card, ease, options);
        final isLearning = sr.queue == CardQueue.learning ||
            sr.queue == CardQueue.relearning;
        if (isLearning) {
          result[ease] = describeNextReview(sr.due, true);
        } else {
          result[ease] = describeNextReview(sr.interval, false);
        }
      } catch (_) {
        // Skip invalid ease for this card state
      }
    }
    return result;
  }

  // --- Learning cards ---

  ScheduleResult _answerLearningCard(
      ReviewCard card, int ease, DeckOptions options) {
    final steps = options.learnSteps;
    if (steps.isEmpty) {
      // No steps, graduate immediately
      return _graduateCard(card, ease, options);
    }

    // Determine current step
    int currentStep;
    if (card.queue == CardQueue.newQueue) {
      currentStep = 0;
      // Initialize left: encode total steps remaining
    } else {
      // left encodes steps remaining
      currentStep = steps.length - (card.left % 1000);
      if (currentStep < 0) currentStep = 0;
      if (currentStep >= steps.length) currentStep = steps.length - 1;
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    switch (ease) {
      case Ease.again:
        // Back to first step
        final delay = steps[0] * 60; // convert minutes to seconds
        return ScheduleResult(
          type: CardType.learning,
          queue: CardQueue.learning,
          due: now + delay,
          interval: 0,
          easeFactor: card.queue == CardQueue.newQueue
              ? options.startingEase
              : card.easeFactor,
          reps: card.reps,
          lapses: card.lapses,
          left: _encodeLeft(steps.length, steps.length),
        );

      case Ease.hard:
        // Repeat current step (or halfway between current and next)
        final delay = steps[currentStep] * 60;
        return ScheduleResult(
          type: CardType.learning,
          queue: CardQueue.learning,
          due: now + delay,
          interval: 0,
          easeFactor: card.queue == CardQueue.newQueue
              ? options.startingEase
              : card.easeFactor,
          reps: card.reps,
          lapses: card.lapses,
          left: _encodeLeft(steps.length - currentStep, steps.length),
        );

      case Ease.good:
        final nextStep = currentStep + 1;
        if (nextStep >= steps.length) {
          // Graduate
          return _graduateCard(card, ease, options);
        }
        final delay = steps[nextStep] * 60;
        return ScheduleResult(
          type: CardType.learning,
          queue: CardQueue.learning,
          due: now + delay,
          interval: 0,
          easeFactor: card.queue == CardQueue.newQueue
              ? options.startingEase
              : card.easeFactor,
          reps: card.reps,
          lapses: card.lapses,
          left: _encodeLeft(steps.length - nextStep, steps.length),
        );

      case Ease.easy:
        // Graduate immediately with easy interval
        return _graduateCard(card, ease, options);

      default:
        throw ArgumentError('Invalid ease: $ease');
    }
  }

  ScheduleResult _graduateCard(ReviewCard card, int ease, DeckOptions options) {
    int interval;
    if (ease == Ease.easy) {
      interval = options.easyInterval;
    } else {
      interval = options.graduatingInterval;
    }
    interval = min(interval, options.maxInterval);

    return ScheduleResult(
      type: CardType.review,
      queue: CardQueue.review,
      due: today + interval,
      interval: interval,
      easeFactor: card.queue == CardQueue.newQueue
          ? options.startingEase
          : card.easeFactor,
      reps: card.reps + 1,
      lapses: card.lapses,
      left: 0,
    );
  }

  int _encodeLeft(int remaining, int total) {
    // Anki encodes: remaining + total * 1000
    return remaining + total * 1000;
  }

  // --- Review cards ---

  ScheduleResult _answerReviewCard(
      ReviewCard card, int ease, DeckOptions options) {
    final overdue = max(0, today - card.due);
    var ef = card.easeFactor;
    int newInterval;

    switch (ease) {
      case Ease.again:
        ef = max(1300, ef - 200);
        newInterval = max(options.minInterval,
            (card.interval * options.newIntervalMultiplier).round());
        // Enter relearning
        if (options.relearningSteps.isNotEmpty) {
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final delay = options.relearningSteps[0] * 60;
          return ScheduleResult(
            type: CardType.relearning,
            queue: CardQueue.relearning,
            due: now + delay,
            interval: newInterval,
            easeFactor: ef,
            reps: card.reps + 1,
            lapses: card.lapses + 1,
            left: _encodeLeft(
                options.relearningSteps.length, options.relearningSteps.length),
          );
        }
        return ScheduleResult(
          type: CardType.review,
          queue: CardQueue.review,
          due: today + newInterval,
          interval: newInterval,
          easeFactor: ef,
          reps: card.reps + 1,
          lapses: card.lapses + 1,
          left: 0,
        );

      case Ease.hard:
        ef = max(1300, ef - 150);
        final hardInterval =
            max(card.interval + 1,
                ((card.interval + overdue / 4.0) * options.hardMultiplier).round());
        newInterval = _constrainInterval(hardInterval, options);
        return ScheduleResult(
          type: CardType.review,
          queue: CardQueue.review,
          due: today + newInterval,
          interval: newInterval,
          easeFactor: ef,
          reps: card.reps + 1,
          lapses: card.lapses,
          left: 0,
        );

      case Ease.good:
        final hardInterval =
            max(card.interval + 1,
                ((card.interval + overdue / 4.0) * options.hardMultiplier).round());
        final goodInterval = max(hardInterval + 1,
            ((card.interval + overdue / 2.0) * ef / 1000.0).round());
        newInterval = _constrainInterval(goodInterval, options);
        return ScheduleResult(
          type: CardType.review,
          queue: CardQueue.review,
          due: today + newInterval,
          interval: newInterval,
          easeFactor: ef,
          reps: card.reps + 1,
          lapses: card.lapses,
          left: 0,
        );

      case Ease.easy:
        ef = ef + 150;
        final hardInterval =
            max(card.interval + 1,
                ((card.interval + overdue / 4.0) * options.hardMultiplier).round());
        final goodInterval = max(hardInterval + 1,
            ((card.interval + overdue / 2.0) * ef / 1000.0).round());
        final easyInterval = max(goodInterval + 1,
            ((card.interval + overdue) * ef / 1000.0 * options.easyBonus).round());
        newInterval = _constrainInterval(easyInterval, options);
        return ScheduleResult(
          type: CardType.review,
          queue: CardQueue.review,
          due: today + newInterval,
          interval: newInterval,
          easeFactor: ef,
          reps: card.reps + 1,
          lapses: card.lapses,
          left: 0,
        );

      default:
        throw ArgumentError('Invalid ease: $ease');
    }
  }

  int _constrainInterval(int interval, DeckOptions options) {
    interval = (interval * options.intervalModifier / 100.0).round();
    return max(1, min(interval, options.maxInterval));
  }

  // --- Relearning cards ---

  ScheduleResult _answerRelearningCard(
      ReviewCard card, int ease, DeckOptions options) {
    final steps = options.relearningSteps;
    if (steps.isEmpty) {
      // No relearning steps, go straight back to review
      return ScheduleResult(
        type: CardType.review,
        queue: CardQueue.review,
        due: today + max(1, card.interval),
        interval: max(1, card.interval),
        easeFactor: card.easeFactor,
        reps: card.reps,
        lapses: card.lapses,
        left: 0,
      );
    }

    int currentStep = steps.length - (card.left % 1000);
    if (currentStep < 0) currentStep = 0;
    if (currentStep >= steps.length) currentStep = steps.length - 1;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    switch (ease) {
      case Ease.again:
        final delay = steps[0] * 60;
        return ScheduleResult(
          type: CardType.relearning,
          queue: CardQueue.relearning,
          due: now + delay,
          interval: card.interval,
          easeFactor: card.easeFactor,
          reps: card.reps,
          lapses: card.lapses,
          left: _encodeLeft(steps.length, steps.length),
        );

      case Ease.good:
        final nextStep = currentStep + 1;
        if (nextStep >= steps.length) {
          // Graduate from relearning
          return ScheduleResult(
            type: CardType.review,
            queue: CardQueue.review,
            due: today + max(1, card.interval),
            interval: max(1, card.interval),
            easeFactor: card.easeFactor,
            reps: card.reps,
            lapses: card.lapses,
            left: 0,
          );
        }
        final delay = steps[nextStep] * 60;
        return ScheduleResult(
          type: CardType.relearning,
          queue: CardQueue.relearning,
          due: now + delay,
          interval: card.interval,
          easeFactor: card.easeFactor,
          reps: card.reps,
          lapses: card.lapses,
          left: _encodeLeft(steps.length - nextStep, steps.length),
        );

      case Ease.easy:
        // Graduate immediately
        final bonusInterval = max(card.interval + 1,
            (card.interval * card.easeFactor / 1000.0).round());
        return ScheduleResult(
          type: CardType.review,
          queue: CardQueue.review,
          due: today + min(bonusInterval, options.maxInterval),
          interval: min(bonusInterval, options.maxInterval),
          easeFactor: card.easeFactor,
          reps: card.reps,
          lapses: card.lapses,
          left: 0,
        );

      default:
        // For hard, treat as good in relearning
        return _answerRelearningCard(card, Ease.good, options);
    }
  }
}
