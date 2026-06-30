import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/geocoding_service.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

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
  final Map<int, Set<Marker>> _markerCache = {};

  static const _categoryColors = {
    '식사': Color(0xFFFF6B4A),
    '관광': Color(0xFF0E5C5C),
    '액티비티': Color(0xFF4A90D9),
    '숙소': Color(0xFF9B59B6),
    '이동': Color(0xFF95A5A6),
  };

  // 장소명 정제 — → 앞부분만 사용, 불필요한 접미사 제거
  String _cleanPlaceName(String name) {
    // 혹시 모를 괄호 내용만 제거
    name = name.replaceAll(RegExp(r'\s*\(.*?\)'), '');
    return name.trim();
  }

  // 지오코딩 쿼리 생성
  // 출발지 정보가 있으면 출발지 기반, 없으면 장소명만
  String _buildQuery(String cleanedName, String category) {
    // 이동 카테고리 중 → 앞부분이면 출발지 도시 이름일 가능성 높음
    // 그냥 cleanedName만 반환 (Google Maps가 잘 찾음)
    return cleanedName;
  }

  Future<BitmapDescriptor> _buildNumberedMarker(int number, Color color) async {
    const size = 80.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final bgPaint = Paint()..color = color;
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 2, bgPaint);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 2, borderPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(
      Uint8List.view(bytes!.buffer),
      width: 36,
      height: 36,
    );
  }

  @override
  void initState() {
    super.initState();
    _geocodeAll();
  }

  Future<void> _geocodeAll() async {
    final service = ref.read(geocodingServiceProvider);

    try {
      for (final day in widget.days) {
        final places = (day['places'] as List).cast<Map>();
        final entries = List<MapEntry<Map, LatLng?>>.filled(
          places.length,
          MapEntry(<String, dynamic>{}, null),
          growable: false,
        );

        final toGeocode = <int, String>{};
        for (var i = 0; i < places.length; i++) {
          entries[i] = MapEntry(places[i], null);
          final rawName = places[i]['name'] as String? ?? '';
          final category = places[i]['category'] as String? ?? '';
          final cleanedName = _cleanPlaceName(rawName);
          if (cleanedName.isEmpty) continue;
          toGeocode[i] = _buildQuery(cleanedName, category);
        }

        if (toGeocode.isNotEmpty) {
          final indices = toGeocode.keys.toList();
          final queries = indices.map((i) => toGeocode[i]!).toList();
          final coords = await service.geocodeAll(queries);

          for (var j = 0; j < indices.length; j++) {
            final idx = indices[j];
            entries[idx] = MapEntry(places[idx], coords[j]);
            debugPrint(
              'geocode [${places[idx]['name']}] → "${queries[j]}" → ${coords[j]}',
            );
          }
        }

        _dayPlaceCoords.add(List.from(entries));
      }

      await _buildAllMarkers();
      if (mounted) setState(() {});
    } catch (e, stack) {
      debugPrint('지오코딩 에러: $e\n$stack');
      if (mounted) setState(() => _error = '지도 데이터를 불러오는 데 실패했어요: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _buildAllMarkers() async {
    for (var dayIdx = 0; dayIdx < _dayPlaceCoords.length; dayIdx++) {
      final entries = _dayPlaceCoords[dayIdx]
          .where((e) => e.value != null)
          .toList();

      final markers = <Marker>{};
      for (var i = 0; i < entries.length; i++) {
        final coord = entries[i].value!;
        final place = entries[i].key;
        final category = place['category'] as String? ?? '';
        final color = _categoryColors[category] ?? const Color(0xFF0E5C5C);

        final icon = await _buildNumberedMarker(i + 1, color);
        markers.add(Marker(
          markerId: MarkerId('marker_${dayIdx}_$i'),
          position: coord,
          icon: icon,
          infoWindow: InfoWindow(
            title: '${i + 1}. ${place['name']}',
            snippet: place['startTime'] as String?,
          ),
        ));
      }

      _markerCache[dayIdx] = markers;
    }
  }

  void _selectDay(int index) {
    setState(() => _selectedDayIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitBoundsToCurrentDay());
  }

  void _fitBoundsToCurrentDay() {
    final coords = _dayPlaceCoords.isNotEmpty
        ? _dayPlaceCoords[_selectedDayIndex]
            .where((e) => e.value != null)
            .map((e) => e.value!)
            .toList()
        : <LatLng>[];

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
        ? _dayPlaceCoords[_selectedDayIndex]
            .where((e) => e.value != null)
            .toList()
        : <MapEntry<Map, LatLng?>>[];

    final markers = _markerCache[_selectedDayIndex] ?? {};
    final polylinePoints = currentEntries.map((e) => e.value!).toList();
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