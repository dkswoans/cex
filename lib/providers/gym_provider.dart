import 'package:flutter/foundation.dart';

import '../data/machine_seed_data.dart';
import '../models/machine_model.dart';
import '../models/reservation_model.dart';
import '../models/usage_log_model.dart';
import '../models/user_model.dart';

class GymProvider extends ChangeNotifier {
  GymProvider() {
    seedOrUpdateMachines();
  }

  UserModel? currentUser;
  final List<MachineModel> machines = [];
  final List<ReservationModel> reservations = [];
  final List<UsageLogModel> usageLogs = [];

  Future<void> seedOrUpdateMachines() async {
    final now = DateTime.now();
    final defaultMachines = createDefaultMachines(now);

    if (machines.isEmpty) {
      machines.addAll(defaultMachines);
      reservations.add(
        ReservationModel(
          reservationId: 'dummy_leg_press_1',
          machineId: 'leg_press',
          machineName: '레그프레스',
          userId: 'dummy_2',
          userName: '박지훈',
          status: ReservationStatus.active,
          createdAt: now.subtract(const Duration(minutes: 6)),
          order: 1,
        ),
      );
    } else {
      for (final seed in defaultMachines) {
        final index = machines.indexWhere(
          (machine) => machine.machineId == seed.machineId,
        );
        if (index == -1) {
          machines.add(seed);
        } else {
          final old = machines[index];
          machines[index] = old.copyWith(
            shortName: seed.shortName,
            zoneName: seed.zoneName,
            mapX: seed.mapX,
            mapY: seed.mapY,
            description: seed.description,
          );
        }
      }
    }
    notifyListeners();
  }

  Future<void> resetMachinesForDemo() async {
    machines.clear();
    reservations.clear();
    usageLogs.clear();
    await seedOrUpdateMachines();
  }

  void login({required String userId, required String name}) {
    currentUser = UserModel(
      userId: userId,
      name: name,
      role: userId == 'admin' ? 'admin' : 'user',
    );
    notifyListeners();
  }

  void logout() {
    currentUser = null;
    notifyListeners();
  }

  MachineModel getMachineById(String machineId) {
    return machines.firstWhere((machine) => machine.machineId == machineId);
  }

  List<ReservationModel> getReservationsByMachine(String machineId) {
    final result =
        reservations
            .where(
              (reservation) =>
                  reservation.machineId == machineId &&
                  (reservation.status == ReservationStatus.waiting ||
                      reservation.status == ReservationStatus.active),
            )
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    return result;
  }

  List<ReservationModel> getMyReservations() {
    final user = currentUser;
    if (user == null) return [];
    final result =
        reservations
            .where(
              (reservation) =>
                  reservation.userId == user.userId &&
                  (reservation.status == ReservationStatus.waiting ||
                      reservation.status == ReservationStatus.active),
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  ReservationModel? getMyReservationForMachine(String machineId) {
    final user = currentUser;
    if (user == null) return null;
    return reservations
        .where(
          (reservation) =>
              reservation.machineId == machineId &&
              reservation.userId == user.userId &&
              (reservation.status == ReservationStatus.waiting ||
                  reservation.status == ReservationStatus.active),
        )
        .firstOrNull;
  }

  String reserveMachine(String machineId) {
    final user = currentUser;
    if (user == null) return '로그인이 필요합니다.';

    final machine = getMachineById(machineId);
    if (machine.status == MachineStatus.repair) {
      return '점검 중인 기구는 예약할 수 없습니다.';
    }

    final alreadyReserved = getMyReservationForMachine(machineId) != null;
    if (alreadyReserved) return '이미 예약한 기구입니다.';

    if (getMyReservations().length >= 2) {
      return '최대 2개까지만 예약할 수 있습니다.';
    }

    final queue = getReservationsByMachine(machineId);
    final order = queue.length + 1;
    reservations.add(
      ReservationModel(
        reservationId:
            '${machineId}_${user.userId}_${DateTime.now().millisecondsSinceEpoch}',
        machineId: machine.machineId,
        machineName: machine.name,
        userId: user.userId,
        userName: user.name,
        status: order == 1 && machine.status == MachineStatus.available
            ? ReservationStatus.active
            : ReservationStatus.waiting,
        createdAt: DateTime.now(),
        order: order,
      ),
    );

    if (machine.status == MachineStatus.available) {
      _replaceMachine(machine.copyWith(status: MachineStatus.reserved));
    }

    notifyListeners();
    return '예약이 완료되었습니다.';
  }

  String cancelReservation(String reservationId) {
    final index = reservations.indexWhere(
      (reservation) => reservation.reservationId == reservationId,
    );
    if (index == -1) return '예약을 찾을 수 없습니다.';

    final machineId = reservations[index].machineId;
    reservations[index] = reservations[index].copyWith(
      status: ReservationStatus.cancelled,
    );
    _reorderReservations(machineId);
    _refreshMachineReservationState(machineId);
    notifyListeners();
    return '예약이 취소되었습니다.';
  }

  String startUsingMachine(String machineId) {
    final user = currentUser;
    if (user == null) return '로그인이 필요합니다.';

    final machine = getMachineById(machineId);
    if (machine.status == MachineStatus.repair) {
      return '점검 중인 기구입니다.';
    }

    final usingOther = machines.any(
      (item) =>
          item.currentUserId == user.userId && item.machineId != machineId,
    );
    if (usingOther) return '이미 다른 기구를 사용 중입니다.';

    if (machine.status == MachineStatus.using &&
        machine.currentUserId != user.userId) {
      return '현재 사용 중인 기구입니다.';
    }

    final activeReservation = reservations
        .where(
          (reservation) =>
              reservation.machineId == machineId &&
              reservation.userId == user.userId &&
              reservation.status == ReservationStatus.active,
        )
        .firstOrNull;

    if (machine.status == MachineStatus.reserved && activeReservation == null) {
      return '첫 번째 예약자만 사용할 수 있습니다.';
    }

    if (machine.status != MachineStatus.available &&
        machine.status != MachineStatus.reserved &&
        machine.currentUserId != user.userId) {
      return '사용을 시작할 수 없습니다.';
    }

    final now = DateTime.now();
    _replaceMachine(
      machine.copyWith(
        status: MachineStatus.using,
        currentUserId: user.userId,
        currentUserName: user.name,
        startedAt: now,
        endAt: now.add(Duration(minutes: machine.maxUseMinutes)),
      ),
    );

    if (activeReservation != null) {
      final index = reservations.indexWhere(
        (reservation) =>
            reservation.reservationId == activeReservation.reservationId,
      );
      reservations[index] = reservations[index].copyWith(
        status: ReservationStatus.completed,
      );
      _reorderReservations(machineId);
    }

    notifyListeners();
    return '사용을 시작했습니다.';
  }

  String finishUsingMachine(String machineId) {
    final user = currentUser;
    if (user == null) return '로그인이 필요합니다.';

    final machine = getMachineById(machineId);
    if (machine.currentUserId != user.userId) {
      return '본인이 사용 중인 기구만 종료할 수 있습니다.';
    }

    final now = DateTime.now();
    final startedAt = machine.startedAt ?? now;
    usageLogs.add(
      UsageLogModel(
        logId: '${machineId}_${user.userId}_${now.millisecondsSinceEpoch}',
        machineId: machine.machineId,
        machineName: machine.name,
        userId: user.userId,
        userName: user.name,
        startedAt: startedAt,
        endedAt: now,
        usedMinutes: now.difference(startedAt).inMinutes,
      ),
    );

    final waiting =
        reservations
            .where(
              (reservation) =>
                  reservation.machineId == machineId &&
                  reservation.status == ReservationStatus.waiting,
            )
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));

    if (waiting.isEmpty) {
      _replaceMachine(
        machine.copyWith(
          status: MachineStatus.available,
          clearCurrentUser: true,
          clearTimes: true,
        ),
      );
    } else {
      final next = waiting.first;
      final index = reservations.indexWhere(
        (reservation) => reservation.reservationId == next.reservationId,
      );
      reservations[index] = next.copyWith(status: ReservationStatus.active);
      _replaceMachine(
        machine.copyWith(
          status: MachineStatus.reserved,
          clearCurrentUser: true,
          clearTimes: true,
        ),
      );
      _reorderReservations(machineId);
    }

    notifyListeners();
    return '사용이 종료되었습니다.';
  }

  int getRemainingMinutes(MachineModel machine) {
    final endAt = machine.endAt;
    if (endAt == null) return 0;
    final minutes = endAt.difference(DateTime.now()).inMinutes;
    return minutes < 0 ? 0 : minutes + 1;
  }

  int getWaitingCount(String machineId) {
    return reservations
        .where(
          (reservation) =>
              reservation.machineId == machineId &&
              reservation.status == ReservationStatus.waiting,
        )
        .length;
  }

  int getEstimatedWaitMinutes(String machineId, String userId) {
    final machine = getMachineById(machineId);
    final reservation = reservations
        .where(
          (item) =>
              item.machineId == machineId &&
              item.userId == userId &&
              (item.status == ReservationStatus.waiting ||
                  item.status == ReservationStatus.active),
        )
        .firstOrNull;
    if (reservation == null || reservation.status == ReservationStatus.active) {
      return 0;
    }

    final aheadCount = getReservationsByMachine(
      machineId,
    ).where((item) => item.order < reservation.order).length;
    final remaining = machine.status == MachineStatus.using
        ? getRemainingMinutes(machine)
        : 0;
    return remaining + aheadCount * machine.maxUseMinutes;
  }

  void _replaceMachine(MachineModel machine) {
    final index = machines.indexWhere(
      (item) => item.machineId == machine.machineId,
    );
    machines[index] = machine;
  }

  void _reorderReservations(String machineId) {
    final active =
        reservations
            .where(
              (reservation) =>
                  reservation.machineId == machineId &&
                  reservation.status == ReservationStatus.active,
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final waiting =
        reservations
            .where(
              (reservation) =>
                  reservation.machineId == machineId &&
                  reservation.status == ReservationStatus.waiting,
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    var order = 1;
    for (final reservation in [...active, ...waiting]) {
      final index = reservations.indexWhere(
        (item) => item.reservationId == reservation.reservationId,
      );
      reservations[index] = reservations[index].copyWith(order: order);
      order++;
    }
  }

  void _refreshMachineReservationState(String machineId) {
    final machine = getMachineById(machineId);
    if (machine.status == MachineStatus.using ||
        machine.status == MachineStatus.repair) {
      return;
    }
    final queue = getReservationsByMachine(machineId);
    _replaceMachine(
      machine.copyWith(
        status: queue.isEmpty
            ? MachineStatus.available
            : MachineStatus.reserved,
      ),
    );
  }
}
