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
  });

  final String reservationId;
  final String machineId;
  final String machineName;
  final String userId;
  final String userName;
  final ReservationStatus status;
  final DateTime createdAt;
  final int order;

  ReservationModel copyWith({
    String? reservationId,
    String? machineId,
    String? machineName,
    String? userId,
    String? userName,
    ReservationStatus? status,
    DateTime? createdAt,
    int? order,
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
    };
  }

  static DateTime? _dateFromMap(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.parse(value as String);
  }
}
