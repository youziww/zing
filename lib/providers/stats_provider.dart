import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/stats_service.dart';

final todayStatsProvider = FutureProvider<TodayStats>((ref) async {
  final service = StatsService();
  return await service.getTodayStats();
});

final dailyStatsProvider =
    FutureProvider.family<List<DailyStats>, int>((ref, days) async {
  final service = StatsService();
  return await service.getDailyStats(days);
});

final forecastProvider =
    FutureProvider.family<List<ForecastEntry>, int>((ref, days) async {
  final service = StatsService();
  return await service.getForecast(days);
});
