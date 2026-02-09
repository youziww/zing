import '../database/card_dao.dart';
import '../database/review_dao.dart';
import '../database/database_helper.dart';
import '../models/card.dart';
import '../models/review_log.dart';
import '../scheduler/scheduler.dart';
import '../scheduler/deck_options.dart';

/// Manages study sessions.
class StudyService {
  final CardDao _cardDao = CardDao();
  final ReviewDao _reviewDao = ReviewDao();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Get the study queue for a deck: learning cards first, then reviews, then new.
  Future<List<ReviewCard>> getStudyQueue(int deckId, DeckOptions options) async {
    final col = await _dbHelper.getCollection();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // 1. Learning cards (due now)
    final learning = await _cardDao.getLearningCards(deckId, now);

    // 2. Review cards (due today)
    final reviews = await _cardDao.getReviewCards(deckId, col.today);

    // 3. New cards (limited by daily max)
    final newStudied = await _cardDao.getNewCardsStudiedToday(deckId);
    final newLimit = options.maxNewPerDay - newStudied;
    final newCards = newLimit > 0
        ? await _cardDao.getNewCards(deckId, newLimit)
        : <ReviewCard>[];

    return [...learning, ...reviews, ...newCards];
  }

  /// Answer a card with the given ease rating.
  Future<ReviewCard> answerCard(
      ReviewCard card, int ease, DeckOptions options) async {
    final col = await _dbHelper.getCollection();
    final scheduler = Scheduler(
      today: col.today,
      dayCutoff: col.dayStartTimestamp,
    );

    final result = scheduler.answerCard(card, ease, options);
    final updatedCard = result.applyTo(card);

    // Save card update
    await _cardDao.update(updatedCard);

    // Write review log
    final log = ReviewLog(
      id: DateTime.now().millisecondsSinceEpoch,
      cardId: card.id,
      ease: ease,
      interval: updatedCard.interval,
      lastInterval: card.interval,
      factor: updatedCard.easeFactor,
      time: 0, // TODO: track actual review time
      type: _getReviewType(card),
    );
    await _reviewDao.insert(log);

    return updatedCard;
  }

  int _getReviewType(ReviewCard card) {
    switch (card.queue) {
      case CardQueue.newQueue:
      case CardQueue.learning:
        return 0; // learn
      case CardQueue.review:
        return 1; // review
      case CardQueue.relearning:
        return 2; // relearn
      default:
        return 0;
    }
  }

  /// Get card counts for a deck.
  Future<Map<String, int>> getCardCounts(int deckId) async {
    return await _cardDao.getCardCounts(deckId);
  }

  /// Get the next review times for button labels.
  Map<int, String> getNextReviewTimes(
      ReviewCard card, DeckOptions options, int today, int dayCutoff) {
    final scheduler = Scheduler(today: today, dayCutoff: dayCutoff);
    return scheduler.getNextReviewTimes(card, options);
  }
}
