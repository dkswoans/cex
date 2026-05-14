enum MachineStatus { available, using, reserved, repair }

class MachineModel {
  const MachineModel({
    required this.machineId,
    required this.name,
    required this.shortName,
    required this.zoneName,
    required this.status,
    required this.maxUseMinutes,
    required this.mapX,
    required this.mapY,
    this.description,
    this.currentUserId,
    this.currentUserName,
    this.startedAt,
    this.endAt,
  });

  final String machineId;
  final String name;
  final String shortName;
  final String zoneName;
  final MachineStatus status;
  final int maxUseMinutes;
  final double mapX;
  final double mapY;
  final String? description;
  final String? currentUserId;
  final String? currentUserName;
  final DateTime? startedAt;
  final DateTime? endAt;

  MachineModel copyWith({
    String? machineId,
    String? name,
    String? shortName,
    String? zoneName,
    MachineStatus? status,
    int? maxUseMinutes,
    double? mapX,
    double? mapY,
    String? description,
    String? currentUserId,
    String? currentUserName,
    DateTime? startedAt,
    DateTime? endAt,
    bool clearCurrentUser = false,
    bool clearTimes = false,
  }) {
    return MachineModel(
      machineId: machineId ?? this.machineId,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      zoneName: zoneName ?? this.zoneName,
      status: status ?? this.status,
      maxUseMinutes: maxUseMinutes ?? this.maxUseMinutes,
      mapX: mapX ?? this.mapX,
      mapY: mapY ?? this.mapY,
      description: description ?? this.description,
      currentUserId: clearCurrentUser
          ? null
          : currentUserId ?? this.currentUserId,
      currentUserName: clearCurrentUser
          ? null
          : currentUserName ?? this.currentUserName,
      startedAt: clearTimes ? null : startedAt ?? this.startedAt,
      endAt: clearTimes ? null : endAt ?? this.endAt,
    );
  }

  factory MachineModel.fromMap(Map<String, dynamic> map) {
    return MachineModel(
      machineId: map['machineId'] as String,
      name: map['name'] as String,
      shortName: map['shortName'] as String? ?? map['name'] as String,
      zoneName: map['zoneName'] as String? ?? '',
      status: MachineStatus.values.byName(map['status'] as String),
      maxUseMinutes: map['maxUseMinutes'] as int,
      mapX: (map['mapX'] as num?)?.toDouble() ?? 0.5,
      mapY: (map['mapY'] as num?)?.toDouble() ?? 0.5,
      description: map['description'] as String?,
      currentUserId: map['currentUserId'] as String?,
      currentUserName: map['currentUserName'] as String?,
      startedAt: _dateFromMap(map['startedAt']),
      endAt: _dateFromMap(map['endAt']),
    );
  }

  factory MachineModel.fromSupabase(Map<String, dynamic> map) {
    return MachineModel(
      machineId: map['id'] as String,
      name: map['name'] as String,
      shortName: map['short_name'] as String? ?? map['name'] as String,
      zoneName: map['zone_name'] as String? ?? '',
      status: MachineStatus.values.byName(map['status'] as String),
      maxUseMinutes: map['max_use_minutes'] as int,
      mapX: (map['map_x'] as num?)?.toDouble() ?? 0.5,
      mapY: (map['map_y'] as num?)?.toDouble() ?? 0.5,
      description: map['description'] as String?,
      currentUserId: map['current_user_id'] as String?,
      currentUserName: map['current_user_name'] as String?,
      startedAt: _dateFromMap(map['started_at']),
      endAt: _dateFromMap(map['end_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'machineId': machineId,
      'name': name,
      'shortName': shortName,
      'zoneName': zoneName,
      'status': status.name,
      'maxUseMinutes': maxUseMinutes,
      'mapX': mapX,
      'mapY': mapY,
      'description': description,
      'currentUserId': currentUserId,
      'currentUserName': currentUserName,
      'startedAt': startedAt?.toIso8601String(),
      'endAt': endAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': machineId,
      'name': name,
      'short_name': shortName,
      'zone_name': zoneName,
      'status': status.name,
      'max_use_minutes': maxUseMinutes,
      'map_x': mapX,
      'map_y': mapY,
      'description': description,
      'current_user_id': currentUserId,
      'current_user_name': currentUserName,
      'started_at': startedAt?.toIso8601String(),
      'end_at': endAt?.toIso8601String(),
    };
  }

  static DateTime? _dateFromMap(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.parse(value as String);
  }
}
