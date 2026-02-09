import '../database/review_dao.dart';
import '../database/card_dao.dart';
import '../database/database_helper.dart';

class StatsService {
  final ReviewDao _reviewDao = ReviewDao();
  final CardDao _cardDao = CardDao();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Get today's study statistics.
  Future<TodayStats> getTodayStats() async {
    final col = await _dbHelper.getCollection();
    final dayStartMs = col.dayStartTimestamp * 1000;
    final reviews = await _reviewDao.getToday(dayStartMs);

    int totalReviews = reviews.length;
    int correctCount = 0;
    int totalTimeMs = 0;

    for (final r in reviews) {
      if (r.ease >= 2) correctCount++;
      totalTimeMs += r.time;
    }

    return TodayStats(
      reviewCount: totalReviews,
      correctCount: correctCount,
      totalTimeMs: totalTimeMs,
      accuracy: totalReviews > 0 ? correctCount / totalReviews : 0,
    );
  }

  /// Get daily review counts for the past N days.
  Future<List<DailyStats>> getDailyStats(int days) async {
    final col = await _dbHelper.getCollection();
    final result = <DailyStats>[];

    for (int i = days - 1; i >= 0; i--) {
      final dayNum = col.today - i;
      final dayStart = (col.crt + dayNum * 86400) * 1000;
      final dayEnd = dayStart + 86400 * 1000;

      final reviews = await _reviewDao.getInRange(dayStart, dayEnd);
      int correct = 0;
      for (final r in reviews) {
        if (r.ease >= 2) correct++;
      }

      result.add(DailyStats(
        date: DateTime.fromMillisecondsSinceEpoch(dayStart),
        reviewCount: reviews.length,
        correctCount: correct,
      ));
    }

    return result;
  }

  /// Get future due card forecast for the next N days.
  Future<List<ForecastEntry>> getForecast(int days) async {
    final col = await _dbHelper.getCollection();
    final cards = await _cardDao.getAll();
    final result = <ForecastEntry>[];

    for (int i = 0; i < days; i++) {
      final dayNum = col.today + i;
      int dueCount = 0;

      for (final card in cards) {
        if (card.queue == 2 && card.due <= dayNum) {
          if (i == 0 || card.due == dayNum) {
            dueCount++;
          }
        }
      }

      result.add(ForecastEntry(
        date: DateTime.now().add(Duration(days: i)),
        dueCount: dueCount,
      ));
    }

    return result;
  }

  /// Get deck-specific stats.
  Future<Map<String, int>> getDeckStats(int deckId) async {
    return await _cardDao.getCardCounts(deckId);
  }
}

class TodayStats {
  final int reviewCount;
  final int correctCount;
  final int totalTimeMs;
  final double accuracy;

  TodayStats({
    required this.reviewCount,
    required this.correctCount,
    required this.totalTimeMs,
    required this.accuracy,
  });
}

class DailyStats {
  final DateTime date;
  final int reviewCount;
  final int correctCount;

  DailyStats({
    required this.date,
    required this.reviewCount,
    required this.correctCount,
  });

  double get accuracy => reviewCount > 0 ? correctCount / reviewCount : 0;
}

class ForecastEntry {
  final DateTime date;
  final int dueCount;

  ForecastEntry({required this.date, required this.dueCount});
}
