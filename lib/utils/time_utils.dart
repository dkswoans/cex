String formatDateTime(DateTime? dateTime) {
  if (dateTime == null) return '-';
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '${dateTime.month}/${dateTime.day} $hour:$minute';
}

String formatTimeOnly(DateTime? dateTime) {
  if (dateTime == null) return '-';
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatRemainingMinutes(int minutes) {
  if (minutes <= 0) return '0분';
  if (minutes < 60) return '$minutes분';
  final hours = minutes ~/ 60;
  final remain = minutes % 60;
  return remain == 0 ? '$hours시간' : '$hours시간 $remain분';
}
