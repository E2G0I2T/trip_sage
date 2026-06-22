import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class TripBudgetScreen extends StatefulWidget {
  final String destination;
  final List<Map> days;
  final int totalBudget;

  const TripBudgetScreen({
    super.key,
    required this.destination,
    required this.days,
    required this.totalBudget,
  });

  @override
  State<TripBudgetScreen> createState() => _TripBudgetScreenState();
}

class _TripBudgetScreenState extends State<TripBudgetScreen> {
  int? _touchedPieIndex;

  static const _categoryColors = {
    '식사': Color(0xFFFF6B4A),
    '관광': Color(0xFF0E5C5C),
    '액티비티': Color(0xFF4A90D9),
    '숙소': Color(0xFF9B59B6),
    '이동': Color(0xFF95A5A6),
  };

  Map<String, int> _calcCategoryTotals() {
    final totals = <String, int>{};
    for (final day in widget.days) {
      final places = (day['places'] as List).cast<Map>();
      for (final place in places) {
        final category = place['category'] as String? ?? '기타';
        final cost = (place['estimatedCost'] as num?)?.toInt() ?? 0;
        totals[category] = (totals[category] ?? 0) + cost;
      }
    }
    return totals;
  }

  List<int> _calcDailyTotals() {
    return widget.days.map((day) {
      final places = (day['places'] as List).cast<Map>();
      return places.fold<int>(
        0,
        (sum, place) => sum + ((place['estimatedCost'] as num?)?.toInt() ?? 0),
      );
    }).toList();
  }

  String _formatWon(int amount) {
    if (amount >= 10000) {
      final man = amount ~/ 10000;
      final rem = amount % 10000;
      return rem == 0 ? '$man만원' : '$man만 ${rem}원';
    }
    return '$amount원';
  }

  @override
  Widget build(BuildContext context) {
    final categoryTotals = _calcCategoryTotals();
    final dailyTotals = _calcDailyTotals();
    final grandTotal = categoryTotals.values.fold(0, (a, b) => a + b);
    final remaining = widget.totalBudget - grandTotal;
    final colorScheme = Theme.of(context).colorScheme;

    final pieEntries = categoryTotals.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: Text('${widget.destination} 예산')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 예산 요약 카드
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('총 예산',
                                style: Theme.of(context).textTheme.bodySmall),
                            Text(
                              _formatWon(widget.totalBudget),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('예상 지출',
                                style: Theme.of(context).textTheme.bodySmall),
                            Text(
                              _formatWon(grandTotal),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('남은 예산',
                                style: Theme.of(context).textTheme.bodySmall),
                            Text(
                              _formatWon(remaining.abs()),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: remaining >= 0
                                        ? const Color(0xFF1D9E75)
                                        : colorScheme.error,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: widget.totalBudget > 0
                            ? (grandTotal / widget.totalBudget).clamp(0.0, 1.0)
                            : 0,
                        minHeight: 8,
                        backgroundColor:
                            colorScheme.primary.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          remaining >= 0
                              ? colorScheme.primary
                              : colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 카테고리별 파이차트
            Text('카테고리별 지출',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (event, response) {
                              setState(() {
                                if (response?.touchedSection != null) {
                                  _touchedPieIndex = response!
                                      .touchedSection!.touchedSectionIndex;
                                } else {
                                  _touchedPieIndex = null;
                                }
                              });
                            },
                          ),
                          sections: pieEntries.asMap().entries.map((entry) {
                            final i = entry.key;
                            final e = entry.value;
                            final isTouched = i == _touchedPieIndex;
                            final color = _categoryColors[e.key] ??
                                Colors.grey;
                            return PieChartSectionData(
                              value: e.value.toDouble(),
                              color: color,
                              radius: isTouched ? 80 : 68,
                              title: isTouched
                                  ? '${(e.value / grandTotal * 100).toStringAsFixed(1)}%'
                                  : '',
                              titleStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: pieEntries.map((e) {
                        final color =
                            _categoryColors[e.key] ?? Colors.grey;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${e.key} ${_formatWon(e.value)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 일별 바차트
            Text('일별 예상 지출', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                child: SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (dailyTotals.reduce((a, b) => a > b ? a : b) *
                              1.3)
                          .toDouble(),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              _formatWon(rod.toY.toInt()),
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) => Text(
                              '${value.toInt() + 1}일',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 48,
                            getTitlesWidget: (value, meta) => Text(
                              _formatWon(value.toInt()),
                              style: const TextStyle(fontSize: 9),
                            ),
                          ),
                        ),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval:
                            dailyTotals.reduce((a, b) => a > b ? a : b) /
                                4,
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: dailyTotals.asMap().entries.map((entry) {
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.toDouble(),
                              color: colorScheme.primary,
                              width: 24,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 카테고리별 상세
            Text('카테고리별 상세', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...pieEntries.map((e) {
              final color = _categoryColors[e.key] ?? Colors.grey;
              final ratio = grandTotal > 0 ? e.value / grandTotal : 0.0;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(e.key,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                          Text(
                            _formatWon(e.value),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: ratio.toDouble(),
                          minHeight: 4,
                          backgroundColor: color.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}