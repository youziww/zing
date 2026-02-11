import 'package:flutter_test/flutter_test.dart';
import 'package:zing/models/card.dart';
import 'package:zing/scheduler/scheduler.dart';
import 'package:zing/scheduler/deck_options.dart';
import 'package:zing/scheduler/card_state.dart';

void main() {
  late Scheduler scheduler;
  const options = DeckOptions();

  setUp(() {
    scheduler = Scheduler(today: 100, dayCutoff: 1000000);
  });

  group('SM-2 Scheduler - Learning Cards', () {
    test('new card + Again: goes to first learning step', () {
      final card = ReviewCard(
        id: 1,
        noteId: 1,
        deckId: 1,
        type: CardType.newCard,
        queue: CardQueue.newQueue,
      );

      final result = scheduler.answerCard(card, Ease.again, options);

      expect(result.type, CardType.learning);
      expect(result.queue, CardQueue.learning);
      expect(result.easeFactor, options.startingEase);
    });

    test('new card + Good: advances to next step', () {
      final card = ReviewCard(
        id: 1,
        noteId: 1,
        deckId: 1,
        type: CardType.newCard,
        queue: CardQueue.newQueue,
      );

      final result = scheduler.answerCard(card, Ease.good, options);

      // Default steps are [1, 10], so Good from step 0 -> step 1
      expect(result.type, CardType.learning);
      expect(result.queue, CardQueue.learning);
    });

    test('new card + Easy: graduates immediately with easy interval', () {
      final card = ReviewCard(
        id: 1,
        noteId: 1,
        deckId: 1,
        type: CardType.newCard,
        queue: CardQueue.newQueue,
      );

      final result = scheduler.answerCard(card, Ease.easy, options);

      expect(result.type, CardType.review);
      expect(result.queue, CardQueue.review);
      expect(result.interval, options.easyInterval);
      expect(result.due, 100 + options.easyInterval);
    });

    test('learning card at last step + Good: graduates with graduating interval', () {
      final card = ReviewCard(
        id: 1,
        noteId: 1,
        deckId: 1,
        type: CardType.learning,
        queue: CardQueue.learning,
        left: 1 + 2 * 1000, // 1 step remaining, 2 total
      );

      final result = scheduler.answerCard(card, Ease.good, options);

      expect(result.type, CardType.review);
      expect(result.queue, CardQueue.review);
      expect(result.interval, options.graduatingInterval);
    });
  });

  group('SM-2 Scheduler - Review Cards', () {
    test('review card + Again: ease decreases by 200, enters relearning', () {
      final card = ReviewCard(
        id: 1,
        noteId: 1,
        deckId: 1,
        type: CardType.review,
        queue: CardQueue.review,
        interval: 10,
        easeFactor: 2500,
        due: 95, // 5 days overdue
        reps: 5,
        lapses: 0,
      );

      final result = scheduler.answerCard(card, Ease.again, options);

      expect(result.easeFactor, 2300);
      expect(result.lapses, 1);
      expect(result.queue, CardQueue.relearning);
      expect(result.type, CardType.relearning);
    });

    test('review card + Hard: ease decreases by 150', () {
      final card = ReviewCard(
        id: 1,
        noteId: 1,
        deckId: 1,
        type: CardType.review,
        queue: CardQueue.review,
        interval: 10,
        easeFactor: 2500,
        due: 100,
        reps: 5,
      );

      final result = scheduler.answerCard(card, Ease.hard, options);

      expect(result.easeFactor, 2350);
      expect(result.type, CardType.review);
      expect(result.queue, CardQueue.review);
      expect(result.interval, greaterThan(10));
    });

    test('review card + Good: ease stays same', () {
      final card = ReviewCard(
        id: 1,
        noteId: 1,
        deckId: 1,
        type: CardType.review,
        queue: CardQueue.review,
        interval: 10,
        easeFactor: 2500,
        due: 100,
        reps: 5,
      );

      final result = scheduler.answerCard(card, Ease.good, options);

      expect(result.easeFactor, 2500);
      expect(result.interval, greaterThan(10));
    });

    test('review card + Easy: ease increases by 150', () {
      final card = ReviewCard(
        id: 1,
        noteId: 1,
        deckId: 1,
        type: CardType.review,
        queue: CardQueue.review,
        interval: 10,
        easeFactor: 2500,
        due: 100,
        reps: 5,
      );

      final result = scheduler.answerCard(card, Ease.easy, options);

      expect(result.easeFactor, 2650);
      expect(result.interval, greaterThan(10));
    });

    test('ease does not go below 1300', () {
      final card = ReviewCard(
        id: 1,
        noteId: 1,
        deckId: 1,
        type: CardType.review,
        queue: CardQueue.review,
        interval: 10,
        easeFactor: 1300,
        due: 100,
        reps: 5,
      );

      final result = scheduler.answerCard(card, Ease.again, options);

      expect(result.easeFactor, 1300); // min is 1300
    });

    test('overdue card gets bonus from overdue days', () {
      final card = ReviewCard(
        id: 1,
        noteId: 1,
        deckId: 1,
        type: CardType.review,
        queue: CardQueue.review,
        interval: 10,
        easeFactor: 2500,
        due: 90, // 10 days overdue
        reps: 5,
      );

      final resultOverdue = scheduler.answerCard(card, Ease.good, options);

      final cardOnTime = card.copyWith(due: 100);
      final resultOnTime = scheduler.answerCard(cardOnTime, Ease.good, options);

      // Overdue card should get a longer interval
      expect(resultOverdue.interval, greaterThan(resultOnTime.interval));
    });

    test('interval is constrained by maxInterval', () {
      final card = ReviewCard(
        id: 1,
        noteId: 1,
        deckId: 1,
        type: CardType.review,
        queue: CardQueue.review,
        interval: 30000,
        easeFactor: 5000,
        due: 0, // very overdue
        reps: 100,
      );

      final constrained = const DeckOptions(maxInterval: 365);
      final result = scheduler.answerCard(card, Ease.easy, constrained);

      expect(result.interval, lessThanOrEqualTo(365));
    });
  });

  group('SM-2 Scheduler - Relearning Cards', () {
    test('relearning + Again: back to first relearn step', () {
      final card = ReviewCard(
        id: 1,
        noteId: 1,
        deckId: 1,
        type: CardType.relearning,
        queue: CardQueue.relearning,
        interval: 5,
        easeFactor: 2300,
        left: 1 + 1 * 1000, // 1 step remaining out of 1
      );

      final result = scheduler.answerCard(card, Ease.again, options);

      expect(result.type, CardType.relearning);
      expect(result.queue, CardQueue.relearning);
    });

    test('relearning + Good at last step: returns to review', () {
      final card = ReviewCard(
        id: 1,
        noteId: 1,
        deckId: 1,
        type: CardType.relearning,
        queue: CardQueue.relearning,
        interval: 5,
        easeFactor: 2300,
        left: 1 + 1 * 1000,
      );

      final result = scheduler.answerCard(card, Ease.good, options);

      expect(result.type, CardType.review);
      expect(result.queue, CardQueue.review);
      expect(result.interval, greaterThanOrEqualTo(1));
    });

    test('relearning + Easy: graduates with bonus interval', () {
      final card = ReviewCard(
        id: 1,
        noteId: 1,
        deckId: 1,
        type: CardType.relearning,
        queue: CardQueue.relearning,
        interval: 5,
        easeFactor: 2500,
        left: 1 + 1 * 1000,
      );

      final result = scheduler.answerCard(card, Ease.easy, options);

      expect(result.type, CardType.review);
      expect(result.queue, CardQueue.review);
      // Easy should give a bonus
      expect(result.interval, greaterThan(5));
    });
  });

  group('SM-2 Scheduler - Next Review Times', () {
    test('returns times for all ease levels', () {
      final card = ReviewCard(
        id: 1,
        noteId: 1,
        deckId: 1,
        type: CardType.newCard,
        queue: CardQueue.newQueue,
      );

      final times = scheduler.getNextReviewTimes(card, options);

      expect(times.containsKey(Ease.again), true);
      expect(times.containsKey(Ease.good), true);
      expect(times.containsKey(Ease.easy), true);
    });
  });

  group('DeckOptions', () {
    test('default values are sensible', () {
      const opts = DeckOptions();
      expect(opts.learnSteps, [1, 10]);
      expect(opts.graduatingInterval, 1);
      expect(opts.easyInterval, 4);
      expect(opts.startingEase, 2500);
      expect(opts.maxNewPerDay, 20);
    });

    test('serialization round-trip', () {
      const opts = DeckOptions(
        learnSteps: [1, 5, 15],
        maxNewPerDay: 30,
        easyInterval: 5,
      );

      final map = opts.toMap();
      final restored = DeckOptions.fromMap(map);

      expect(restored.learnSteps, [1, 5, 15]);
      expect(restored.maxNewPerDay, 30);
      expect(restored.easyInterval, 5);
    });
  });

  group('Undo - Snapshot Integrity', () {
    test('copyWith snapshot preserves original state after answer', () {
      final card = ReviewCard(
        id: 1, noteId: 1, deckId: 1,
        type: CardType.review,
        queue: CardQueue.review,
        due: 90,
        interval: 10,
        easeFactor: 2500,
        reps: 5,
        lapses: 0,
      );

      final snapshot = card.copyWith();
      final result = scheduler.answerCard(card, Ease.again, options);
      final updated = result.applyTo(card);

      // Snapshot retains pre-answer values
      expect(snapshot.type, CardType.review);
      expect(snapshot.queue, CardQueue.review);
      expect(snapshot.due, 90);
      expect(snapshot.interval, 10);
      expect(snapshot.easeFactor, 2500);
      expect(snapshot.reps, 5);
      expect(snapshot.lapses, 0);

      // Updated card has changed
      expect(updated.queue, CardQueue.relearning);
      expect(updated.lapses, 1);
      expect(updated.easeFactor, 2300);
    });

    test('snapshot is independent from original card mutations', () {
      final card = ReviewCard(
        id: 2, noteId: 2, deckId: 1,
        type: CardType.newCard,
        queue: CardQueue.newQueue,
        easeFactor: 2500,
      );

      final snapshot = card.copyWith();

      // Mutate original via applyTo
      final result = scheduler.answerCard(card, Ease.good, options);
      result.applyTo(card);

      // Snapshot fields unchanged
      expect(snapshot.type, CardType.newCard);
      expect(snapshot.queue, CardQueue.newQueue);
      expect(snapshot.easeFactor, 2500);
      expect(snapshot.reps, 0);
    });

    test('snapshot preserves all fields for review card undo', () {
      final card = ReviewCard(
        id: 3, noteId: 3, deckId: 1,
        type: CardType.review,
        queue: CardQueue.review,
        due: 95,
        interval: 20,
        easeFactor: 1800,
        reps: 12,
        lapses: 3,
        left: 0,
        originalDue: 0,
        originalDeckId: 0,
      );

      final snapshot = card.copyWith();

      // Answer Easy — big changes
      final result = scheduler.answerCard(card, Ease.easy, options);
      final updated = result.applyTo(card);

      // Verify snapshot has exact original values
      expect(snapshot.id, card.id);
      expect(snapshot.interval, 20);
      expect(snapshot.easeFactor, 1800);
      expect(snapshot.reps, 12);
      expect(snapshot.lapses, 3);
      expect(snapshot.due, 95);

      // Updated card differs
      expect(updated.easeFactor, 1950);
      expect(updated.interval, greaterThan(20));
      expect(updated.reps, 13);
    });
  });

  group('Card State', () {
    test('describeNextReview for learning (seconds)', () {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect(describeNextReview(now + 30, true), '< 1 min');
      expect(describeNextReview(now + 120, true), '2 min');
      expect(describeNextReview(now + 7200, true), '2 h');
    });

    test('describeNextReview for review (days)', () {
      expect(describeNextReview(1, false), '1 d');
      expect(describeNextReview(15, false), '15 d');
      expect(describeNextReview(60, false), '2.0 mo');
      expect(describeNextReview(400, false), '1.1 yr');
    });
  });
}
