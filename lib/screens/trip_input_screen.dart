import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/itinerary_service.dart';
import 'package:flutter/services.dart';

class TripInputScreen extends ConsumerStatefulWidget {
  const TripInputScreen({super.key});

  @override
  ConsumerState<TripInputScreen> createState() => _TripInputScreenState();
}

class _TripInputScreenState extends ConsumerState<TripInputScreen> {
  final _destinationController = TextEditingController();
  final _originController = TextEditingController();
  final _budgetController = TextEditingController();
  DateTimeRange? _dateRange;
  String _travelStyle = '맛집 위주';
  String _transportMode = '대중교통';
  bool _loading = false;
  String? _errorMessage;

  static const _travelStyles = ['맛집 위주', '관광 위주', '휴양', '액티비티'];
  static const _transportModes = ['대중교통', '자가용', '도보', '자전거'];

  @override
  void dispose() {
    _destinationController.dispose();
    _originController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _dateRange,
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  Future<void> _submit() async {
    if (_destinationController.text.trim().isEmpty) {
      setState(() => _errorMessage = '목적지를 입력해주세요.');
      return;
    }
    if (_dateRange == null) {
      setState(() => _errorMessage = '여행 날짜를 선택해주세요.');
      return;
    }
    final budget = int.tryParse(_budgetController.text.trim().replaceAll(',', ''));
    if (budget == null || budget <= 0) {
      setState(() => _errorMessage = '예산을 올바르게 입력해주세요.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(itineraryServiceProvider);
      final result = await service.generateItinerary(
        destination: _destinationController.text.trim(),
        origin: _originController.text.trim(),
        startDate: _dateRange!.start,
        endDate: _dateRange!.end,
        budget: budget,
        travelStyle: _travelStyle,
        transportMode: _transportMode,
      );

      if (!mounted) return;
      context.push('/result', extra: {
        'destination': _destinationController.text.trim(),
        'origin': _originController.text.trim(),
        'startDate': _dateRange!.start,
        'endDate': _dateRange!.end,
        'budget': budget,
        'travelStyle': _travelStyle,
        'transportMode': _transportMode,
        'itinerary': result,
      });
    } catch (e) {
      setState(() => _errorMessage = '일정 생성에 실패했어요: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatRange(DateTimeRange range) {
    String fmt(DateTime d) =>
        '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
    final days = range.duration.inDays + 1;
    return '${fmt(range.start)} ~ ${fmt(range.end)} ($days일)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('새 여행 만들기')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('어디로 떠나볼까요?',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),

              // 출발지
              Text('출발지', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: _originController,
                decoration: const InputDecoration(
                  hintText: '예: 서울, 부산 (선택 사항)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // 목적지
              Text('목적지', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: _destinationController,
                decoration: const InputDecoration(
                  hintText: '예: 제주도, 부산, 도쿄',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // 여행 날짜
              Text('여행 날짜', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _pickDateRange,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.centerLeft,
                  ),
                  child: Text(
                      _dateRange == null ? '날짜 선택' : _formatRange(_dateRange!)),
                ),
              ),
              const SizedBox(height: 20),

              // 총 예산
              Text('총 예산 (원)', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    hintText: '예: 500,000',
                    border: OutlineInputBorder(),
                    suffixText: '원',
                ),
              ),
              const SizedBox(height: 20),

              // 여행 스타일
              Text('여행 스타일', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _travelStyles.map((style) {
                  return ChoiceChip(
                    label: Text(style),
                    selected: _travelStyle == style,
                    onSelected: (_) => setState(() => _travelStyle = style),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // 이동 수단
              Text('이동 수단', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _transportModes.map((mode) {
                  return ChoiceChip(
                    label: Text(mode),
                    selected: _transportMode == mode,
                    onSelected: (_) => setState(() => _transportMode = mode),
                  );
                }).toList(),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(_errorMessage!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ],

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('AI 일정 만들기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  @override
    void initState() {
    super.initState();
    _budgetController.addListener(() {
        final text = _budgetController.text.replaceAll(',', '');
        final number = int.tryParse(text);
        if (number == null) return;
        final formatted = _formatNumber(number);
        if (_budgetController.text != formatted) {
        _budgetController.value = TextEditingValue(
            text: formatted,
            selection: TextSelection.collapsed(offset: formatted.length),
        );
        }
    });
    }

    String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
    );
  }
}