import 'package:flutter/material.dart';

import '../models/reservation_model.dart';
import '../utils/status_utils.dart';
import '../utils/time_utils.dart';

class ReservationCard extends StatelessWidget {
  const ReservationCard({
    super.key,
    required this.reservation,
    required this.estimatedWaitMinutes,
    required this.onCancel,
  });

  final ReservationModel reservation;
  final int estimatedWaitMinutes;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    reservation.machineName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _ReservationBadge(status: reservation.status),
              ],
            ),
            const SizedBox(height: 12),
            _Line(
              label: '대기 순서',
              value: reservation.status == ReservationStatus.active
                  ? '사용 가능'
                  : '${reservation.order}번째',
            ),
            _Line(
              label: '예상 대기',
              value: formatRemainingMinutes(estimatedWaitMinutes),
            ),
            _Line(label: '예약 시간', value: formatDateTime(reservation.createdAt)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onCancel,
                style: FilledButton.styleFrom(backgroundColor: redColor),
                child: const Text('예약 취소'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: const TextStyle(color: mutedTextColor)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: textColor)),
          ),
        ],
      ),
    );
  }
}

class _ReservationBadge extends StatelessWidget {
  const _ReservationBadge({required this.status});

  final ReservationStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status == ReservationStatus.active ? greenColor : amberColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        reservationStatusText(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
