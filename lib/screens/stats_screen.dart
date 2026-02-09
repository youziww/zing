import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/stats_provider.dart';
import '../services/stats_service.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayStats = ref.watch(todayStatsProvider);
    final dailyStats = ref.watch(dailyStatsProvider(30));
    final forecast = ref.watch(forecastProvider(14));

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Statistics'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Today's stats
            _SectionHeader(title: 'Today'),
            todayStats.when(
              data: (stats) => _TodayStatsCard(stats: stats),
              loading: () => const Center(child: CupertinoActivityIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 24),

            // Review history
            _SectionHeader(title: 'Last 30 Days'),
            dailyStats.when(
              data: (stats) => _ReviewHistoryChart(stats: stats),
              loading: () => const Center(child: CupertinoActivityIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 24),

            // Forecast
            _SectionHeader(title: 'Forecast (14 days)'),
            forecast.when(
              data: (entries) => _ForecastChart(entries: entries),
              loading: () => const Center(child: CupertinoActivityIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _TodayStatsCard extends StatelessWidget {
  final TodayStats stats;
  const _TodayStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGroupedBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatValue(
            label: 'Reviews',
            value: '${stats.reviewCount}',
            color: CupertinoColors.systemBlue,
          ),
          _StatValue(
            label: 'Correct',
            value: '${stats.correctCount}',
            color: CupertinoColors.systemGreen,
          ),
          _StatValue(
            label: 'Accuracy',
            value: stats.reviewCount > 0
                ? '${(stats.accuracy * 100).toStringAsFixed(0)}%'
                : '-',
            color: CupertinoColors.systemOrange,
          ),
        ],
      ),
    );
  }
}

class _StatValue extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatValue({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: CupertinoColors.systemGrey,
          ),
        ),
      ],
    );
  }
}

class _ReviewHistoryChart extends StatelessWidget {
  final List<DailyStats> stats;
  const _ReviewHistoryChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const Text('No review history yet.');
    }

    final maxCount =
        stats.fold<int>(0, (m, s) => s.reviewCount > m ? s.reviewCount : m);
    final barMaxHeight = 100.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGroupedBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SizedBox(
            height: barMaxHeight + 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: stats.map((s) {
                final height = maxCount > 0
                    ? (s.reviewCount / maxCount * barMaxHeight)
                    : 0.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (s.reviewCount > 0)
                          Text(
                            '${s.reviewCount}',
                            style: const TextStyle(fontSize: 8),
                          ),
                        Container(
                          height: height,
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBlue,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(stats.first.date),
                style: const TextStyle(
                    fontSize: 10, color: CupertinoColors.systemGrey),
              ),
              Text(
                _formatDate(stats.last.date),
                style: const TextStyle(
                    fontSize: 10, color: CupertinoColors.systemGrey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.month}/${d.day}';
}

class _ForecastChart extends StatelessWidget {
  final List<ForecastEntry> entries;
  const _ForecastChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Text('No forecast data.');
    }

    final maxDue =
        entries.fold<int>(0, (m, e) => e.dueCount > m ? e.dueCount : m);
    final barMaxHeight = 80.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGroupedBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SizedBox(
            height: barMaxHeight + 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: entries.map((e) {
                final height = maxDue > 0
                    ? (e.dueCount / maxDue * barMaxHeight)
                    : 0.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (e.dueCount > 0)
                          Text(
                            '${e.dueCount}',
                            style: const TextStyle(fontSize: 9),
                          ),
                        Container(
                          height: height,
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGreen,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today',
                style: TextStyle(
                    fontSize: 10, color: CupertinoColors.systemGrey),
              ),
              Text(
                '+${entries.length - 1}d',
                style: const TextStyle(
                    fontSize: 10, color: CupertinoColors.systemGrey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
