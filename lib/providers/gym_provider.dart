import 'package:flutter/foundation.dart';

import '../data/machine_seed_data.dart';
import '../models/machine_model.dart';
import '../models/reservation_model.dart';
import '../models/usage_log_model.dart';
import '../models/user_model.dart';
import '../services/supabase_config.dart';

class GymProvider extends ChangeNotifier {
  GymProvider() {
    syncFromDatabase();
  }

  UserModel? currentUser;
  final List<MachineModel> machines = [];
  final List<ReservationModel> reservations = [];
  final List<UsageLogModel> usageLogs = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> syncFromDatabase() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final machineRows = await SupabaseConfig.client
          .from('machines')
          .select()
          .order('id');

      if (machineRows.isEmpty) {
        await seedOrUpdateMachines();
        return;
      }

      final reservationRows = await SupabaseConfig.client
          .from('reservations')
          .select()
          .order('created_at');
      final usageLogRows = await SupabaseConfig.client
          .from('usage_logs')
          .select()
          .order('ended_at');

      machines
        ..clear()
        ..addAll(
          machineRows.map(
            (row) => MachineModel.fromSupabase(Map<String, dynamic>.from(row)),
          ),
        );
      reservations
        ..clear()
        ..addAll(
          reservationRows.map(
            (row) =>
                ReservationModel.fromSupabase(Map<String, dynamic>.from(row)),
          ),
        );
      usageLogs
        ..clear()
        ..addAll(
          usageLogRows.map(
            (row) => UsageLogModel.fromSupabase(Map<String, dynamic>.from(row)),
          ),
        );
    } catch (error) {
      errorMessage = 'Supabase 데이터를 불러오지 못했습니다: $error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> seedOrUpdateMachines() async {
    final now = DateTime.now();
    final defaultMachines = createDefaultMachines(now);

    await SupabaseConfig.client
        .from('machines')
        .upsert(
          defaultMachines.map((machine) => machine.toSupabase()).toList(),
        );
    await SupabaseConfig.client.from('reservations').upsert([
      ReservationModel(
        reservationId: 'dummy_leg_press_1',
        machineId: 'leg_press',
        machineName: '레그프레스',
        userId: 'dummy_2',
        userName: '박지훈',
        status: ReservationStatus.active,
        createdAt: now.subtract(const Duration(minutes: 6)),
        order: 1,
        reservedStartAt: now.subtract(const Duration(minutes: 6)),
        reservedEndAt: now.add(const Duration(minutes: 14)),
        claimExpiresAt: now.subtract(const Duration(minutes: 5)),
      ).toSupabase(),
    ]);

    await syncFromDatabase();
  }

  Future<void> resetMachinesForDemo() async {
    await SupabaseConfig.client.from('reservations').delete().neq('id', '');
    await SupabaseConfig.client.from('usage_logs').delete().neq('id', '');
    await SupabaseConfig.client.from('machines').delete().neq('id', '');
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

  Future<String> reserveMachine(String machineId) async {
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
    final now = DateTime.now();
    final reservation = ReservationModel(
      reservationId:
          '${machineId}_${user.userId}_${now.millisecondsSinceEpoch}',
      machineId: machine.machineId,
      machineName: machine.name,
      userId: user.userId,
      userName: user.name,
      status: order == 1 && machine.status == MachineStatus.available
          ? ReservationStatus.active
          : ReservationStatus.waiting,
      createdAt: now,
      order: order,
      reservedStartAt: now,
      reservedEndAt: now.add(Duration(minutes: machine.maxUseMinutes)),
      claimExpiresAt: now.add(const Duration(minutes: 1)),
    );

    try {
      await SupabaseConfig.client
          .from('reservations')
          .insert(reservation.toSupabase());
      if (machine.status == MachineStatus.available) {
        await _updateMachine(machine.copyWith(status: MachineStatus.reserved));
      }
      await syncFromDatabase();
      return '예약이 완료되었습니다.';
    } catch (error) {
      return '예약에 실패했습니다: $error';
    }
  }

  Future<String> cancelReservation(String reservationId) async {
    final index = reservations.indexWhere(
      (reservation) => reservation.reservationId == reservationId,
    );
    if (index == -1) return '예약을 찾을 수 없습니다.';

    final machineId = reservations[index].machineId;
    try {
      await SupabaseConfig.client
          .from('reservations')
          .update({'status': ReservationStatus.cancelled.name})
          .eq('id', reservationId);
      await _reorderReservations(machineId);
      await _refreshMachineReservationState(machineId);
      await syncFromDatabase();
      return '예약을 취소했습니다.';
    } catch (error) {
      return '예약 취소에 실패했습니다: $error';
    }
  }

  Future<String> startUsingMachine(String machineId) async {
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
    final updatedMachine = machine.copyWith(
      status: MachineStatus.using,
      currentUserId: user.userId,
      currentUserName: user.name,
      startedAt: now,
      endAt: now.add(Duration(minutes: machine.maxUseMinutes)),
    );

    try {
      await _updateMachine(updatedMachine);
      if (activeReservation != null) {
        await SupabaseConfig.client
            .from('reservations')
            .update({'status': ReservationStatus.completed.name})
            .eq('id', activeReservation.reservationId);
        await _reorderReservations(machineId);
      }
      await syncFromDatabase();
      return '사용을 시작했습니다.';
    } catch (error) {
      return '사용 시작에 실패했습니다: $error';
    }
  }

  Future<String> finishUsingMachine(String machineId) async {
    final user = currentUser;
    if (user == null) return '로그인이 필요합니다.';

    final machine = getMachineById(machineId);
    if (machine.currentUserId != user.userId) {
      return '본인이 사용 중인 기구만 종료할 수 있습니다.';
    }

    final now = DateTime.now();
    final startedAt = machine.startedAt ?? now;
    final usageLog = UsageLogModel(
      logId: '${machineId}_${user.userId}_${now.millisecondsSinceEpoch}',
      machineId: machine.machineId,
      machineName: machine.name,
      userId: user.userId,
      userName: user.name,
      startedAt: startedAt,
      endedAt: now,
      usedMinutes: now.difference(startedAt).inMinutes,
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

    try {
      await SupabaseConfig.client
          .from('usage_logs')
          .insert(usageLog.toSupabase());

      if (waiting.isEmpty) {
        await _updateMachine(
          machine.copyWith(
            status: MachineStatus.available,
            clearCurrentUser: true,
            clearTimes: true,
          ),
        );
      } else {
        final next = waiting.first;
        await SupabaseConfig.client
            .from('reservations')
            .update({'status': ReservationStatus.active.name})
            .eq('id', next.reservationId);
        await _updateMachine(
          machine.copyWith(
            status: MachineStatus.reserved,
            clearCurrentUser: true,
            clearTimes: true,
          ),
        );
        await _reorderReservations(machineId);
      }

      await syncFromDatabase();
      return '사용을 종료했습니다.';
    } catch (error) {
      return '사용 종료에 실패했습니다: $error';
    }
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

  Future<void> _updateMachine(MachineModel machine) async {
    final values = machine.toSupabase()..remove('id');
    await SupabaseConfig.client
        .from('machines')
        .update(values)
        .eq('id', machine.machineId);
  }

  Future<void> _reorderReservations(String machineId) async {
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
      await SupabaseConfig.client
          .from('reservations')
          .update({'queue_order': order})
          .eq('id', reservation.reservationId);
      order++;
    }
  }

  Future<void> _refreshMachineReservationState(String machineId) async {
    final machine = getMachineById(machineId);
    if (machine.status == MachineStatus.using ||
        machine.status == MachineStatus.repair) {
      return;
    }
    final queue = getReservationsByMachine(machineId);
    await _updateMachine(
      machine.copyWith(
        status: queue.isEmpty
            ? MachineStatus.available
            : MachineStatus.reserved,
      ),
    );
  }
}
