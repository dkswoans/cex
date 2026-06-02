import 'package:flutter/material.dart';

import '../models/reservation_model.dart';
import '../utils/status_utils.dart';
import '../utils/time_utils.dart';
import 'app_design.dart';

class ReservationCard extends StatelessWidget {
  const ReservationCard({
    super.key,
    required this.reservation,
    required this.estimatedWaitMinutes,
    required this.onCancel,
  });

  final ReservationModel reservation;
  final int estimatedWaitMinutes;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return AppRecordCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reservation.machineName,
                  style: AppTextStyles.itemTitle,
                ),
              ),
              _ReservationBadge(status: reservation.status),
            ],
          ),
          const SizedBox(height: 12),
          AppInfoRow(
            label: '대기 순서',
            value: reservation.status == ReservationStatus.active
                ? '사용 가능'
                : '${reservation.order}번째',
          ),
          AppInfoRow(
            label: '예상 대기',
            value: formatRemainingMinutes(estimatedWaitMinutes),
          ),
          AppInfoRow(
            label: '예약 시간',
            value: formatTimeRange(
              reservation.reservedStartAt,
              reservation.reservedEndAt,
            ),
          ),
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
        color: Color.lerp(color, bgColor, 0.18),
        border: Border.all(color: borderColor, width: 2.5),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        reservationStatusText(status),
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
