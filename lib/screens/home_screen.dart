import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/trip_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<Map<String, dynamic>> _trips = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(tripServiceProvider);
      final trips = await service.fetchTrips();
      if (mounted) setState(() => _trips = trips);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteTrip(String tripId) async {
    try {
      final service = ref.read(tripServiceProvider);
      await service.deleteTrip(tripId);
      setState(() => _trips.removeWhere((t) => t['id'] == tripId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('여행이 삭제됐어요.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제에 실패했어요: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(String tripId, String destination) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('여행 삭제'),
        content: Text('$destination 여행을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deleteTrip(tripId);
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    DateTime dt;
    if (ts is Timestamp) {
      dt = ts.toDate();
    } else {
      return '';
    }
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatWon(int amount) {
    if (amount >= 10000) {
      final man = amount ~/ 10000;
      final rem = amount % 10000;
      return rem == 0 ? '$man만원' : '$man만 ${rem}원';
    }
    return '$amount원';
  }

  int _calcDays(dynamic start, dynamic end) {
    if (start is! Timestamp || end is! Timestamp) return 0;
    return end.toDate().difference(start.toDate()).inDays + 1;
  }

  void _openTrip(Map<String, dynamic> trip) {
    final days = (trip['days'] as List).cast<Map>();
    final startDate = (trip['startDate'] as Timestamp).toDate();
    final endDate = (trip['endDate'] as Timestamp).toDate();

    context.push('/result', extra: {
        'tripId': trip['id'] as String,
        'destination': trip['destination'] as String,
        'startDate': startDate,
        'endDate': endDate,
        'budget': trip['budget'] as int,
        'travelStyle': trip['travelStyle'] as String? ?? '',
        'itinerary': {'days': days},
    }).then((_) => _loadTrips()); // ← 이 부분만 추가
  }

  static const _styleEmoji = {
    '맛집 위주': '🍽️',
    '관광 위주': '🏛️',
    '휴양': '🏖️',
    '액티비티': '🧗',
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TripSage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTrips,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('불러오기 실패: $_error'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _loadTrips,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : _trips.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.luggage_outlined,
                              size: 72,
                              color: colorScheme.onSurface.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text(
                            '저장된 여행이 없어요',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '새 여행을 만들어보세요!',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadTrips,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _trips.length,
                        itemBuilder: (context, index) {
                          final trip = _trips[index];
                          final destination = trip['destination'] as String? ?? '';
                          final tripId = trip['id'] as String;
                          final budget = trip['budget'] as int? ?? 0;
                          final style = trip['travelStyle'] as String? ?? '';
                          final days = _calcDays(trip['startDate'], trip['endDate']);
                          final startStr = _formatDate(trip['startDate']);
                          final endStr = _formatDate(trip['endDate']);
                          final emoji = _styleEmoji[style] ?? '✈️';

                          return Dismissible(
                            key: Key(tripId),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: colorScheme.error,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.delete_outline,
                                  color: Colors.white, size: 28),
                            ),
                            confirmDismiss: (_) async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('여행 삭제'),
                                  content: Text('$destination 여행을 삭제할까요?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('취소'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: colorScheme.error,
                                      ),
                                      child: const Text('삭제'),
                                    ),
                                  ],
                                ),
                              );
                              return confirmed ?? false;
                            },
                            onDismissed: (_) => _deleteTrip(tripId),
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () => _openTrip(trip),
                                onLongPress: () =>
                                    _confirmDelete(tripId, destination),
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(emoji,
                                            style: const TextStyle(fontSize: 26)),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              destination,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(fontSize: 17),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$startStr ~ $endStr · $days일',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: colorScheme.onSurface
                                                        .withValues(alpha: 0.6),
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: colorScheme.secondary
                                                        .withValues(alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    _formatWon(budget),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color:
                                                              colorScheme.secondary,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  style,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: colorScheme.onSurface
                                                            .withValues(alpha: 0.5),
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.3)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/input').then((_) => _loadTrips()),
        icon: const Icon(Icons.add),
        label: const Text('새 여행'),
      ),
    );
  }
}