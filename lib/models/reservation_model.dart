enum ReservationStatus { waiting, active, completed, cancelled }

class ReservationModel {
  const ReservationModel({
    required this.reservationId,
    required this.machineId,
    required this.machineName,
    required this.userId,
    required this.userName,
    required this.status,
    required this.createdAt,
    required this.order,
    this.reservedStartAt,
    this.reservedEndAt,
    this.claimExpiresAt,
  });

  final String reservationId;
  final String machineId;
  final String machineName;
  final String userId;
  final String userName;
  final ReservationStatus status;
  final DateTime createdAt;
  final int order;
  final DateTime? reservedStartAt;
  final DateTime? reservedEndAt;
  final DateTime? claimExpiresAt;

  ReservationModel copyWith({
    String? reservationId,
    String? machineId,
    String? machineName,
    String? userId,
    String? userName,
    ReservationStatus? status,
    DateTime? createdAt,
    int? order,
    DateTime? reservedStartAt,
    DateTime? reservedEndAt,
    DateTime? claimExpiresAt,
  }) {
    return ReservationModel(
      reservationId: reservationId ?? this.reservationId,
      machineId: machineId ?? this.machineId,
      machineName: machineName ?? this.machineName,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      order: order ?? this.order,
      reservedStartAt: reservedStartAt ?? this.reservedStartAt,
      reservedEndAt: reservedEndAt ?? this.reservedEndAt,
      claimExpiresAt: claimExpiresAt ?? this.claimExpiresAt,
    );
  }

  factory ReservationModel.fromMap(Map<String, dynamic> map) {
    return ReservationModel(
      reservationId: map['reservationId'] as String,
      machineId: map['machineId'] as String,
      machineName: map['machineName'] as String,
      userId: map['userId'] as String,
      userName: map['userName'] as String,
      status: ReservationStatus.values.byName(map['status'] as String),
      createdAt: _dateFromMap(map['createdAt'])!,
      order: map['order'] as int,
      reservedStartAt: _dateFromMap(map['reservedStartAt']),
      reservedEndAt: _dateFromMap(map['reservedEndAt']),
      claimExpiresAt: _dateFromMap(map['claimExpiresAt']),
    );
  }

  factory ReservationModel.fromSupabase(Map<String, dynamic> map) {
    return ReservationModel(
      reservationId: map['id'] as String,
      machineId: map['machine_id'] as String,
      machineName: map['machine_name'] as String,
      userId: map['user_id'] as String,
      userName: map['user_name'] as String,
      status: ReservationStatus.values.byName(map['status'] as String),
      createdAt: _dateFromMap(map['created_at'])!,
      order: map['queue_order'] as int,
      reservedStartAt: _dateFromMap(map['reserved_start_at']),
      reservedEndAt: _dateFromMap(map['reserved_end_at']),
      claimExpiresAt: _dateFromMap(map['claim_expires_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reservationId': reservationId,
      'machineId': machineId,
      'machineName': machineName,
      'userId': userId,
      'userName': userName,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'order': order,
      'reservedStartAt': reservedStartAt?.toIso8601String(),
      'reservedEndAt': reservedEndAt?.toIso8601String(),
      'claimExpiresAt': claimExpiresAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toSupabase() {
    final startAt = reservedStartAt ?? createdAt;
    final endAt = reservedEndAt ?? startAt.add(const Duration(minutes: 15));
    return {
      'id': reservationId,
      'machine_id': machineId,
      'machine_name': machineName,
      'user_id': userId,
      'user_name': userName,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'queue_order': order,
      'reserved_start_at': startAt.toIso8601String(),
      'reserved_end_at': endAt.toIso8601String(),
      'claim_expires_at':
          (claimExpiresAt ?? startAt.add(const Duration(minutes: 1)))
              .toIso8601String(),
    };
  }

  static DateTime? _dateFromMap(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.parse(value as String);
  }
}
