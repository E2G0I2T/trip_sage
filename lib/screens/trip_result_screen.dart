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
  bool _saved = false;
  late Map _itinerary;

  @override
  void initState() {
    super.initState();
    _itinerary = widget.data['itinerary'] as Map;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final service = ref.read(tripServiceProvider);
      await service.saveTrip(
        destination: widget.data['destination'] as String,
        startDate: widget.data['startDate'] as DateTime,
        endDate: widget.data['endDate'] as DateTime,
        budget: widget.data['budget'] as int,
        travelStyle: widget.data['travelStyle'] as String,
        days: _itinerary['days'] as List,
      );
      if (!mounted) return;
      setState(() => _saved = true);
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
            setState(() {
              _itinerary = updated;
              _saved = false;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.data['destination'] as String? ?? '';
    final days = (_itinerary['days'] as List).cast<Map>();

    return Scaffold(
      appBar: AppBar(
        title: Text('$destination 일정'),
        actions: [
            IconButton(
                onPressed: () => context.push('/budget', extra: {
                'destination': destination,
                'days': days,
                'totalBudget': widget.data['budget'] as int,
                }),
                icon: const Icon(Icons.pie_chart_outline),
            ),
            IconButton(
                onPressed: () => context.push('/map', extra: {
                'destination': destination,
                'days': days,
                }),
                icon: const Icon(Icons.map_outlined),
            ),
            IconButton(
                onPressed: _saving || _saved ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : Icon(_saved ? Icons.bookmark : Icons.bookmark_border),
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
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${day['dayIndex']}일차 · ${day['date']}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ...places.map((place) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: SizedBox(
                        width: 56,
                        child: Text(
                          place['startTime'] as String? ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      title: Text(place['name'] as String? ?? ''),
                      subtitle: Text(place['memo'] as String? ?? ''),
                      trailing: Text(
                        '${place['estimatedCost']}원',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
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