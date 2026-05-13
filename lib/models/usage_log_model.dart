class UsageLogModel {
  const UsageLogModel({
    required this.logId,
    required this.machineId,
    required this.machineName,
    required this.userId,
    required this.userName,
    required this.startedAt,
    required this.endedAt,
    required this.usedMinutes,
  });

  final String logId;
  final String machineId;
  final String machineName;
  final String userId;
  final String userName;
  final DateTime startedAt;
  final DateTime endedAt;
  final int usedMinutes;

  UsageLogModel copyWith({
    String? logId,
    String? machineId,
    String? machineName,
    String? userId,
    String? userName,
    DateTime? startedAt,
    DateTime? endedAt,
    int? usedMinutes,
  }) {
    return UsageLogModel(
      logId: logId ?? this.logId,
      machineId: machineId ?? this.machineId,
      machineName: machineName ?? this.machineName,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      usedMinutes: usedMinutes ?? this.usedMinutes,
    );
  }

  factory UsageLogModel.fromMap(Map<String, dynamic> map) {
    return UsageLogModel(
      logId: map['logId'] as String,
      machineId: map['machineId'] as String,
      machineName: map['machineName'] as String,
      userId: map['userId'] as String,
      userName: map['userName'] as String,
      startedAt: _dateFromMap(map['startedAt'])!,
      endedAt: _dateFromMap(map['endedAt'])!,
      usedMinutes: map['usedMinutes'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'logId': logId,
      'machineId': machineId,
      'machineName': machineName,
      'userId': userId,
      'userName': userName,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'usedMinutes': usedMinutes,
    };
  }

  static DateTime? _dateFromMap(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.parse(value as String);
  }
}
