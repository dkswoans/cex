import 'package:flutter/material.dart';

import '../models/machine_model.dart';
import '../models/reservation_model.dart';

const bgColor = Color(0xFFFFF0A3);
const surfaceColor = Color(0xFFF15AB8);
const textColor = Color(0xFF15236D);
const mutedTextColor = Color(0xFF664096);
const redColor = Color(0xFFEF4444);
const blueColor = Color(0xFF22C1DA);
const greenColor = Color(0xFF58D96A);
const amberColor = Color(0xFFF69B2C);
const borderColor = Color(0xFF111111);
const strongBorderColor = Color(0xFFEF4444);
const lightGrayColor = Color(0xFFD5EB63);

Color machineStatusColor(MachineStatus status) {
  return switch (status) {
    MachineStatus.available => greenColor,
    MachineStatus.using => redColor,
    MachineStatus.reserved => amberColor,
    MachineStatus.repair => const Color(0xFF6D6D6D),
  };
}

String machineStatusText(MachineStatus status) {
  return switch (status) {
    MachineStatus.available => '사용 가능',
    MachineStatus.using => '사용 중',
    MachineStatus.reserved => '찜당함',
    MachineStatus.repair => '점검 중',
  };
}

String reservationStatusText(ReservationStatus status) {
  return switch (status) {
    ReservationStatus.waiting => '예약 대기',
    ReservationStatus.active => '찜당함',
    ReservationStatus.completed => '완료',
    ReservationStatus.cancelled => '취소됨',
  };
}
