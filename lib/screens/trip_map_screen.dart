import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/geocoding_service.dart';

class TripMapScreen extends ConsumerStatefulWidget {
  final String destination;
  final List<Map> days;

  const TripMapScreen({super.key, required this.destination, required this.days});

  @override
  ConsumerState<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends ConsumerState<TripMapScreen> {
  int _selectedDayIndex = 0;
  bool _loading = true;
  String? _error;
  final List<List<MapEntry<Map, LatLng?>>> _dayPlaceCoords = [];
  GoogleMapController? _mapController;

  static const _skipCategories = {'이동'};

  String _cleanPlaceName(String name) {
    const removeSuffixes = [
      ' 도착 및 이동', ' 도착', ' 이동', ' 체크인', ' 및 이동',
      ' 출발', ' 반납', ' 수령', ' 및 출발',
    ];
    var cleaned = name;
    for (final suffix in removeSuffixes) {
      if (cleaned.endsWith(suffix)) {
        cleaned = cleaned.substring(0, cleaned.length - suffix.length);
        break;
      }
    }
    return cleaned.trim();
  }

  @override
  void initState() {
    super.initState();
    debugPrint('TripMapScreen initState 시작, days 개수: ${widget.days.length}');
    _geocodeAll();
  }

  Future<void> _geocodeAll() async {
    debugPrint('_geocodeAll 시작');
    final service = ref.read(geocodingServiceProvider);
    debugPrint('서비스 인스턴스 생성됨');

    try {
      for (final day in widget.days) {
        debugPrint('day 처리 중: ${day['dayIndex']}');
        final places = (day['places'] as List).cast<Map>();
        final entries = List<MapEntry<Map, LatLng?>>.filled(
          places.length,
          MapEntry(<String, dynamic>{}, null),
          growable: false,
        );

        final toGeocode = <int, String>{};
        for (var i = 0; i < places.length; i++) {
          final category = places[i]['category'] as String? ?? '';
          entries[i] = MapEntry(places[i], null);
          if (_skipCategories.contains(category)) continue;
          final rawName = places[i]['name'] as String? ?? '';
          final cleanedName = _cleanPlaceName(rawName);
          toGeocode[i] = '$cleanedName, ${widget.destination}';
        }

        if (toGeocode.isNotEmpty) {
          final indices = toGeocode.keys.toList();
          final queries = indices.map((i) => toGeocode[i]!).toList();
          debugPrint('지오코딩 요청: $queries');

          final coords = await service.geocodeAll(queries);
          debugPrint('지오코딩 결과: $coords');

          for (var j = 0; j < indices.length; j++) {
            final idx = indices[j];
            entries[idx] = MapEntry(places[idx], coords[j]);
          }
        }

        _dayPlaceCoords.add(List.from(entries));
        debugPrint('day ${day['dayIndex']} 완료');
      }
    } catch (e, stack) {
      debugPrint('지오코딩 에러: $e\n$stack');
      setState(() => _error = '지도 데이터를 불러오는 데 실패했어요: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
      debugPrint('_geocodeAll 완료, _loading = false');
    }
  }

  void _selectDay(int index) {
    setState(() => _selectedDayIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitBoundsToCurrentDay());
  }

  void _fitBoundsToCurrentDay() {
    final coords = _dayPlaceCoords[_selectedDayIndex]
        .where((e) => e.value != null)
        .map((e) => e.value!)
        .toList();

    if (_mapController == null || coords.isEmpty) return;

    if (coords.length == 1) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(coords.first, 14));
      return;
    }

    var minLat = coords.first.latitude, maxLat = coords.first.latitude;
    var minLng = coords.first.longitude, maxLng = coords.first.longitude;
    for (final c in coords) {
      minLat = c.latitude < minLat ? c.latitude : minLat;
      maxLat = c.latitude > maxLat ? c.latitude : maxLat;
      minLng = c.longitude < minLng ? c.longitude : minLng;
      maxLng = c.longitude > maxLng ? c.longitude : maxLng;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.destination} 지도')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('장소 위치를 불러오는 중이에요...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.destination} 지도')),
        body: Center(child: Text(_error!)),
      );
    }

    final currentEntries = _dayPlaceCoords.isNotEmpty
        ? _dayPlaceCoords[_selectedDayIndex].where((e) => e.value != null).toList()
        : <MapEntry<Map, LatLng?>>[];

    final markers = <Marker>{};
    final polylinePoints = <LatLng>[];

    for (var i = 0; i < currentEntries.length; i++) {
      final coord = currentEntries[i].value!;
      final place = currentEntries[i].key;
      markers.add(Marker(
        markerId: MarkerId('marker_$i'),
        position: coord,
        infoWindow: InfoWindow(
          title: '${i + 1}. ${place['name']}',
          snippet: place['startTime'] as String?,
        ),
      ));
      polylinePoints.add(coord);
    }

    final initialTarget = currentEntries.isNotEmpty
        ? currentEntries.first.value!
        : const LatLng(37.5665, 126.9780);

    return Scaffold(
      appBar: AppBar(title: Text('${widget.destination} 지도')),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: widget.days.length,
              itemBuilder: (context, index) {
                final selected = index == _selectedDayIndex;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${widget.days[index]['dayIndex']}일차'),
                    selected: selected,
                    onSelected: (_) => _selectDay(index),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: initialTarget, zoom: 13),
              markers: markers,
              polylines: polylinePoints.length > 1
                  ? {
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: polylinePoints,
                        color: Theme.of(context).colorScheme.secondary,
                        width: 4,
                      ),
                    }
                  : {},
              onMapCreated: (controller) {
                _mapController = controller;
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _fitBoundsToCurrentDay(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}