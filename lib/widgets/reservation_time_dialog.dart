import 'package:flutter/material.dart';

import '../utils/status_utils.dart';
import 'app_design.dart';

typedef EarliestReservationStartResolver = DateTime? Function(int minutes);

class ReservationTimeRequest {
  const ReservationTimeRequest({required this.startAt, required this.minutes});

  final DateTime startAt;
  final int minutes;
}

class ReservationTimeDialog extends StatefulWidget {
  const ReservationTimeDialog({
    super.key,
    required this.maxMinutes,
    this.title = '예약 시간 설정',
    this.confirmLabel = '예약하기',
    this.initialStartAt,
    this.initialMinutes,
    this.findEarliestStartAt,
  });

  final int maxMinutes;
  final String title;
  final String confirmLabel;
  final DateTime? initialStartAt;
  final int? initialMinutes;
  final EarliestReservationStartResolver? findEarliestStartAt;

  @override
  State<ReservationTimeDialog> createState() => _ReservationTimeDialogState();
}

class _ReservationTimeDialogState extends State<ReservationTimeDialog> {
  late final TextEditingController _minutesController;
  late TimeOfDay _startTime;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _startTime = _initialStartTime();
    _minutesController = TextEditingController(
      text: (widget.initialMinutes ?? widget.maxMinutes)
          .clamp(1, widget.maxMinutes)
          .toString(),
    );
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quickPicks = [
      5,
      10,
      15,
      30,
    ].where((m) => m <= widget.maxMinutes).toList();

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('시작 시간', style: AppTextStyles.label),
                      const SizedBox(height: 2),
                      const Text('시간 제한 없음', style: AppTextStyles.label),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: _pickStartTime,
                  child: Text(
                    _formatTime(_startTime),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.findEarliestStartAt != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _setEarliestStartTime,
                  icon: const Icon(Icons.flash_on_rounded),
                  label: const Text('가장 빠른 시간'),
                  style: FilledButton.styleFrom(
                    backgroundColor: greenColor,
                    foregroundColor: borderColor,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('사용 시간 (분)', style: AppTextStyles.label),
            const SizedBox(height: 8),
            if (quickPicks.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: quickPicks.map((minutes) {
                  final selected = _minutesController.text == '$minutes';
                  return GestureDetector(
                    onTap: () {
                      _minutesController.text = '$minutes';
                      setState(() => _errorText = null);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? blueColor : bgColor,
                        border: Border.all(
                          color: selected ? blueColor : borderColor,
                          width: 2.5,
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        '$minutes분',
                        style: TextStyle(
                          color: selected ? borderColor : textColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _minutesController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '직접 입력',
                helperText: '1~${widget.maxMinutes}분',
                errorText: _errorText,
              ),
              onChanged: (_) => setState(() => _errorText = null),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      initialEntryMode: TimePickerEntryMode.dialOnly,
      helpText: '예약 시작 시간',
      cancelText: '취소',
      confirmText: '선택',
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: const ColorScheme.light(
              primary: redColor,
              onPrimary: bgColor,
              surface: bgColor,
              onSurface: borderColor,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: bgColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: borderColor, width: 4),
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              padding: const EdgeInsets.all(18),
              helpTextStyle: const TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
              hourMinuteColor: surfaceColor,
              hourMinuteTextColor: bgColor,
              hourMinuteTextStyle: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
              hourMinuteShape: RoundedRectangleBorder(
                side: const BorderSide(color: borderColor, width: 3),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              dialBackgroundColor: const Color(0xFFFFD7F4),
              dialHandColor: redColor,
              dialTextColor: borderColor,
              dialTextStyle: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0,
              ),
              dayPeriodBorderSide: const BorderSide(
                color: borderColor,
                width: 2.5,
              ),
              dayPeriodColor: surfaceColor,
              dayPeriodTextColor: borderColor,
              dayPeriodTextStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
              dayPeriodShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              entryModeIconColor: textColor,
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: textColor,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: bgColor,
                backgroundColor: redColor,
                side: const BorderSide(color: borderColor, width: 3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _startTime = picked;
      _errorText = null;
    });
  }

  void _setEarliestStartTime() {
    final minutes = _readMinutes();
    if (minutes == null) return;

    final startAt = widget.findEarliestStartAt?.call(minutes);
    if (startAt == null) {
      setState(() {
        _errorText = '예약 가능한 가장 빠른 시간이 없습니다.';
      });
      return;
    }

    final startKst = _koreaTime(startAt);
    setState(() {
      _startTime = TimeOfDay(hour: startKst.hour, minute: startKst.minute);
      _errorText = null;
    });
  }

  void _submit() {
    final minutes = _readMinutes();
    if (minutes == null) return;

    final startAt = _todayKoreaTimeAsUtc(_startTime.hour, _startTime.minute);
    FocusScope.of(context).unfocus();
    Navigator.of(
      context,
    ).pop(ReservationTimeRequest(startAt: startAt, minutes: minutes));
  }

  int? _readMinutes() {
    final minutes = int.tryParse(_minutesController.text.trim());
    if (minutes == null || minutes < 1 || minutes > widget.maxMinutes) {
      setState(() {
        _errorText = '이용 시간은 1~${widget.maxMinutes}분으로 입력하세요.';
      });
      return null;
    }
    return minutes;
  }

  DateTime _todayKoreaTimeAsUtc(int hour, int minute) {
    final nowKst = _koreaTime(DateTime.now());
    var startAt = DateTime.utc(
      nowKst.year,
      nowKst.month,
      nowKst.day,
      hour - 9,
      minute,
    );
    if (_koreaTime(startAt).isBefore(nowKst)) {
      startAt = startAt.add(const Duration(days: 1));
    }
    return startAt;
  }

  DateTime _koreaTime(DateTime dateTime) {
    return dateTime.toUtc().add(const Duration(hours: 9));
  }

  TimeOfDay _initialStartTime() {
    final initialStartAt = widget.initialStartAt;
    if (initialStartAt != null) {
      final initialKst = _koreaTime(initialStartAt);
      return TimeOfDay(hour: initialKst.hour, minute: initialKst.minute);
    }

    final nowKst = _koreaTime(DateTime.now()).add(const Duration(minutes: 1));
    return TimeOfDay(hour: nowKst.hour, minute: nowKst.minute);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
