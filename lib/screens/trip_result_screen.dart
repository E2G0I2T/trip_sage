import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/trip_service.dart';
import 'trip_chat_screen.dart';

class TripResultScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;

  const TripResultScreen({super.key, required this.data});

  @override
  ConsumerState<TripResultScreen> createState() => _TripResultScreenState();
}

class _TripResultScreenState extends ConsumerState<TripResultScreen> {
  bool _saving = false;
  String? _tripId;
  late Map _itinerary;

  static const _categoryIcons = {
    '식사': Icons.restaurant,
    '관광': Icons.photo_camera,
    '액티비티': Icons.directions_run,
    '숙소': Icons.hotel,
    '이동': Icons.directions_transit,
  };

  static const _categoryColors = {
    '식사': Color(0xFFFF6B4A),
    '관광': Color(0xFF0E5C5C),
    '액티비티': Color(0xFF4A90D9),
    '숙소': Color(0xFF9B59B6),
    '이동': Color(0xFF95A5A6),
  };

  @override
  void initState() {
    super.initState();
    _itinerary = widget.data['itinerary'] as Map;
    _tripId = widget.data['tripId'] as String?;
  }

  String _formatWon(dynamic cost) {
    final amount = (cost as num?)?.toInt() ?? 0;
    if (amount >= 10000) {
      final man = amount ~/ 10000;
      final rem = amount % 10000;
      return rem == 0 ? '$man만원' : '$man만 ${rem}원';
    }
    return '$amount원';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final service = ref.read(tripServiceProvider);
      final id = await service.saveTrip(
        destination: widget.data['destination'] as String,
        startDate: widget.data['startDate'] as DateTime,
        endDate: widget.data['endDate'] as DateTime,
        budget: widget.data['budget'] as int,
        travelStyle: widget.data['travelStyle'] as String,
        days: _itinerary['days'] as List,
      );
      if (!mounted) return;
      setState(() => _tripId = id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일정이 저장됐어요.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장에 실패했어요: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _autoSaveAfterEdit(Map updatedItinerary) async {
    final service = ref.read(tripServiceProvider);
    try {
      if (_tripId != null) {
        await service.updateTrip(
          tripId: _tripId!,
          days: updatedItinerary['days'] as List,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('수정 내용이 자동 저장됐어요.')),
          );
        }
      } else {
        final id = await service.saveTrip(
          destination: widget.data['destination'] as String,
          startDate: widget.data['startDate'] as DateTime,
          endDate: widget.data['endDate'] as DateTime,
          budget: widget.data['budget'] as int,
          travelStyle: widget.data['travelStyle'] as String,
          days: updatedItinerary['days'] as List,
        );
        if (mounted) {
          setState(() => _tripId = id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('일정이 자동 저장됐어요.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('자동 저장에 실패했어요: $e')),
        );
      }
    }
  }

  void _openChat() {
    final destination = widget.data['destination'] as String;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => TripChatScreen(
          destination: destination,
          itinerary: _itinerary,
          onItineraryUpdated: (updated) {
            setState(() => _itinerary = updated);
            _autoSaveAfterEdit(updated);
          },
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    final destination = widget.data['destination'] as String;
    final days = (_itinerary['days'] as List).cast<Map>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.pie_chart_outline),
              title: const Text('예산 분석'),
              onTap: () {
                Navigator.pop(context);
                context.push('/budget', extra: {
                  'destination': destination,
                  'days': days,
                  'totalBudget': widget.data['budget'] as int,
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('지도 보기'),
              onTap: () {
                Navigator.pop(context);
                context.push('/map', extra: {
                  'destination': destination,
                  'days': days,
                });
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.data['destination'] as String? ?? '';
    final days = (_itinerary['days'] as List).cast<Map>();
    final isSaved = _tripId != null;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('$destination 일정'),
        actions: [
          IconButton(
            onPressed: _saving || isSaved ? null : _save,
            icon: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
          ),
          IconButton(
            onPressed: () => _showMenu(context),
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: days.length,
        itemBuilder: (context, dayIndex) {
          final day = days[dayIndex];
          final places = (day['places'] as List).cast<Map>();

          return Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 날짜 헤더
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${day['dayIndex']}일차',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      day['date'] as String? ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                ...places.asMap().entries.map((entry) {
                  final i = entry.key;
                  final place = entry.value;
                  final category = place['category'] as String? ?? '';
                  final icon = _categoryIcons[category] ?? Icons.place_outlined;
                  final color = _categoryColors[category] ?? Colors.grey;
                  final activity = place['activity'] as String? ?? '';
                  final memo = place['memo'] as String? ?? '';

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 타임라인
                      SizedBox(
                        width: 56,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 22),
                            Text(
                              place['startTime'] as String? ?? '',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            if (i < places.length - 1)
                              Container(
                                width: 2,
                                height: 72,
                                color:
                                    colorScheme.outline.withValues(alpha: 0.2),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // 카드
                      Expanded(
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 카테고리 아이콘 배지
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(icon, size: 18, color: color),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              place['name'] as String? ?? '',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ),
                                          // 카테고리 배지
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color:
                                                  color.withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              category,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: color,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      // activity 표시 (장소에서 하는 활동)
                                      if (activity.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          activity,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: colorScheme.primary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ],
                                      // memo 표시
                                      if (memo.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          memo,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: colorScheme.onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.attach_money,
                                            size: 13,
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.4),
                                          ),
                                          Text(
                                            _formatWon(place['estimatedCost']),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: colorScheme.onSurface
                                                      .withValues(alpha: 0.6),
                                                ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.access_time,
                                            size: 13,
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.4),
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '${place['durationMinutes']}분',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: colorScheme.onSurface
                                                      .withValues(alpha: 0.6),
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openChat,
        icon: const Icon(Icons.edit_note),
        label: const Text('일정 수정'),
      ),
    );
  }
}