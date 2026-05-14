String formatDateTime(DateTime? dateTime) {
  if (dateTime == null) return '-';
  final local = _toKoreaTime(dateTime);
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.month}/${local.day} $hour:$minute';
}

String formatTimeOnly(DateTime? dateTime) {
  if (dateTime == null) return '-';
  final local = _toKoreaTime(dateTime);
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

DateTime _toKoreaTime(DateTime dateTime) {
  return dateTime.toUtc().add(const Duration(hours: 9));
}

String formatRemainingMinutes(int minutes) {
  if (minutes <= 0) return '0분';
  if (minutes < 60) return '$minutes분';
  final hours = minutes ~/ 60;
  final remain = minutes % 60;
  return remain == 0 ? '$hours시간' : '$hours시간 $remain분';
}
