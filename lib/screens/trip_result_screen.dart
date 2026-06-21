import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/trip_service.dart';

class TripResultScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;

  const TripResultScreen({super.key, required this.data});

  @override
  ConsumerState<TripResultScreen> createState() => _TripResultScreenState();
}

class _TripResultScreenState extends ConsumerState<TripResultScreen> {
  bool _saving = false;
  bool _saved = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final service = ref.read(tripServiceProvider);
      final itinerary = widget.data['itinerary'] as Map;
      await service.saveTrip(
        destination: widget.data['destination'] as String,
        startDate: widget.data['startDate'] as DateTime,
        endDate: widget.data['endDate'] as DateTime,
        budget: widget.data['budget'] as int,
        travelStyle: widget.data['travelStyle'] as String,
        days: itinerary['days'] as List,
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

  @override
  Widget build(BuildContext context) {
    final destination = widget.data['destination'] as String? ?? '';
    final itinerary = widget.data['itinerary'] as Map;
    final days = (itinerary['days'] as List).cast<Map>();

    return Scaffold(
      appBar: AppBar(
        title: Text('$destination 일정'),
        actions: [
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
        padding: const EdgeInsets.all(16),
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
    );
  }
}