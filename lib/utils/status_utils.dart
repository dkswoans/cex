import 'package:flutter/material.dart';

import '../models/machine_model.dart';
import '../models/reservation_model.dart';

const bgColor = Color(0xFFFFF200);
const surfaceColor = Color(0xFFFF4FD8);
const textColor = Color(0xFF0019FF);
const mutedTextColor = Color(0xFF7A00FF);
const redColor = Color(0xFFFF0000);
const blueColor = Color(0xFF00E5FF);
const greenColor = Color(0xFF00FF38);
const amberColor = Color(0xFFFF7A00);
const borderColor = Color(0xFF111111);
const strongBorderColor = Color(0xFFFF0000);
const lightGrayColor = Color(0xFFB6FF00);

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
    MachineStatus.available => '쌉가능',
    MachineStatus.using => '누가씀',
    MachineStatus.reserved => '찜당함',
    MachineStatus.repair => '고장남',
  };
}

String reservationStatusText(ReservationStatus status) {
  return switch (status) {
    ReservationStatus.waiting => '기다려',
    ReservationStatus.active => '니차례',
    ReservationStatus.completed => '끝남',
    ReservationStatus.cancelled => '런함',
  };
}
