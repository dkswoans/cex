import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/machine_seed_data.dart';
import '../models/machine_model.dart';
import '../models/reservation_model.dart';
import '../models/usage_log_model.dart';
import '../models/user_model.dart';
import '../services/supabase_config.dart';

class GymProvider extends ChangeNotifier {
  static const bool _bypassBusinessHoursForTesting = true;
  static const String _multiUserSeparator = '|';

  GymProvider() {
    syncFromDatabase();
    _startReservationTimer();
  }

  UserModel? currentUser;
  final List<MachineModel> machines = [];
  final List<ReservationModel> reservations = [];
  final List<UsageLogModel> usageLogs = [];
  bool isLoading = false;
  String? errorMessage;
  Timer? _reservationTimer;
  bool _isApplyingReservationWindows = false;

  @override
  void dispose() {
    _reservationTimer?.cancel();
    super.dispose();
  }

  Future<void> syncFromDatabase() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final machineRows = await SupabaseConfig.client
          .from('machines')
          .select()
          .order('id');

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
      await _applyReservationWindows();
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
        reservedEndAt: now.add(const Duration(minutes: 9)),
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
          ..sort(_compareReservationsByStartTime);
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
          ..sort(_compareReservationsByStartTime);
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

  bool isUserUsingMachine(String machineId) {
    final user = currentUser;
    if (user == null) return false;
    return reservations.any(
          (reservation) =>
              reservation.machineId == machineId &&
              reservation.userId == user.userId &&
              reservation.status == ReservationStatus.active,
        ) ||
        machines.any(
          (machine) =>
              machine.machineId == machineId &&
              _splitMultiValue(machine.currentUserId).contains(user.userId),
        );
  }

  List<ReservationModel> getActiveReservationsByMachine(String machineId) {
    final result =
        reservations
            .where(
              (reservation) =>
                  reservation.machineId == machineId &&
                  reservation.status == ReservationStatus.active,
            )
            .toList()
          ..sort(_compareReservationsByStartTime);
    return result;
  }

  List<ReservationModel> getCurrentUsersByMachine(String machineId) {
    final machine = getMachineById(machineId);
    final result = [...getActiveReservationsByMachine(machineId)];
    final ids = _splitMultiValue(machine.currentUserId);
    final names = _splitMultiValue(machine.currentUserName);
    final now = DateTime.now();
    for (var index = 0; index < ids.length; index++) {
      final userId = ids[index];
      if (result.any((reservation) => reservation.userId == userId)) {
        continue;
      }
      result.add(
        ReservationModel(
          reservationId: '${machineId}_${userId}_direct',
          machineId: machine.machineId,
          machineName: machine.name,
          userId: userId,
          userName: index < names.length ? names[index] : userId,
          status: ReservationStatus.active,
          createdAt: machine.startedAt ?? now,
          order: result.length + 1,
          reservedStartAt: machine.startedAt,
          reservedEndAt: machine.endAt,
          claimExpiresAt: machine.startedAt,
        ),
      );
    }
    result.sort(_compareReservationsByStartTime);
    return result;
  }

  int getActiveCount(String machineId) {
    return getCurrentUsersByMachine(machineId).length;
  }

  int getMachineCapacity(String machineId) {
    return switch (machineId) {
      'treadmill' => 9,
      'cycle' => 4,
      _ => 1,
    };
  }

  int getMaxUseMinutesForMachine(String machineId) {
    return machineId == 'treadmill' ? 30 : 15;
  }

  int getMaxReservationMinutesForMachine(String machineId) {
    return 15;
  }

  bool hasAvailableUnitNow(String machineId) {
    final now = DateTime.now();
    final activeCount = _overlappingReservationCount(
      machineId,
      startAt: now,
      endAt: now.add(const Duration(minutes: 1)),
    );
    return activeCount < getMachineCapacity(machineId);
  }

  int getRemainingUnitCount(String machineId) {
    final remaining = getMachineCapacity(machineId) - getActiveCount(machineId);
    return remaining < 0 ? 0 : remaining;
  }

  String getMachineMapSummary(String machineId) {
    final capacity = getMachineCapacity(machineId);
    if (capacity <= 1) {
      final waitingCount = getWaitingCount(machineId);
      return waitingCount > 0 ? '대기 $waitingCount' : '대기 0';
    }
    final activeCount = getActiveCount(machineId);
    return '$activeCount/$capacity';
  }

  Future<String> reserveMachine(
    String machineId, {
    required int minutes,
    required DateTime startAt,
  }) async {
    final user = currentUser;
    if (user == null) return '로그인이 필요합니다.';
    final machine = getMachineById(machineId);
    final maxMinutes = getMaxReservationMinutesForMachine(machineId);
    if (minutes < 1 || minutes > maxMinutes) {
      return '예약 시간은 1분부터 $maxMinutes분까지 가능합니다.';
    }

    final reservationError = _validateBusinessWindow(
      startAt: startAt,
      minutes: minutes,
      actionName: '예약',
      requireFuture: true,
    );
    if (reservationError != null) return reservationError;

    await _applyReservationWindows();
    if (machine.status == MachineStatus.repair) {
      return '점검 중인 기구는 예약할 수 없습니다.';
    }

    final alreadyReserved = getMyReservationForMachine(machineId) != null;
    if (alreadyReserved) return '이미 예약한 기구입니다.';

    if (getMyReservations().length >= 2) {
      return '최대 2개까지만 예약할 수 있습니다.';
    }

    final endAt = startAt.add(Duration(minutes: minutes));
    final hasOverlap = getMyReservations().any(
      (reservation) =>
          _reservationOverlaps(reservation, startAt: startAt, endAt: endAt),
    );
    if (hasOverlap) {
      return '이미 같은 시간대에 예약한 기구가 있습니다.';
    }

    final capacity = getMachineCapacity(machineId);
    final overlappingCount = _overlappingReservationCount(
      machineId,
      startAt: startAt,
      endAt: endAt,
    );
    if (overlappingCount >= capacity) {
      return '해당 시간대에 예약 가능한 자리가 없습니다.';
    }

    final queue = reservations.where(
      (reservation) =>
          reservation.machineId == machineId &&
          (reservation.status == ReservationStatus.waiting ||
              reservation.status == ReservationStatus.active),
    );
    final order = queue.length + 1;
    final now = DateTime.now();
    final reservation = ReservationModel(
      reservationId:
          '${machineId}_${user.userId}_${now.millisecondsSinceEpoch}',
      machineId: machine.machineId,
      machineName: machine.name,
      userId: user.userId,
      userName: user.name,
      status: ReservationStatus.waiting,
      createdAt: now,
      order: order,
      reservedStartAt: startAt,
      reservedEndAt: endAt,
      claimExpiresAt: startAt.add(const Duration(minutes: 1)),
    );

    try {
      await SupabaseConfig.client
          .from('reservations')
          .insert(reservation.toSupabase());
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
      reservations[index] = reservations[index].copyWith(
        status: ReservationStatus.cancelled,
      );
      await _reorderReservations(machineId);
      await _refreshMachineReservationState(machineId);
      await syncFromDatabase();
      return '예약을 취소했습니다.';
    } catch (error) {
      return '예약 취소에 실패했습니다: $error';
    }
  }

  Future<String> startUsingMachine(
    String machineId, {
    required int minutes,
  }) async {
    final user = currentUser;
    await _applyReservationWindows();
    if (user == null) return '로그인이 필요합니다.';

    final machine = getMachineById(machineId);
    final maxMinutes = getMaxUseMinutesForMachine(machineId);
    final activeReservation = reservations
        .where(
          (reservation) =>
              reservation.machineId == machineId &&
              reservation.userId == user.userId &&
              reservation.status == ReservationStatus.active,
        )
        .firstOrNull;
    if (minutes < 1 || minutes > maxMinutes) {
      return '사용 시간은 1분부터 $maxMinutes분까지 가능합니다.';
    }

    final businessError = _validateBusinessWindow(
      startAt: DateTime.now(),
      minutes: minutes,
      actionName: '사용',
    );
    if (businessError != null) return businessError;
    if (machine.status == MachineStatus.repair) {
      return '점검 중인 기구입니다.';
    }

    final usingOther =
        reservations.any(
          (reservation) =>
              reservation.userId == user.userId &&
              reservation.machineId != machineId &&
              reservation.status == ReservationStatus.active,
        ) ||
        machines.any(
          (item) =>
              _splitMultiValue(item.currentUserId).contains(user.userId) &&
              item.machineId != machineId,
        );
    if (usingOther) return '이미 다른 기구를 사용 중입니다.';

    if (activeReservation == null && !hasAvailableUnitNow(machineId)) {
      return '현재 사용 가능한 자리가 없습니다.';
    }

    final now = DateTime.now();
    final reservationEndAt = activeReservation?.reservedEndAt;
    if (activeReservation != null &&
        (reservationEndAt == null || !reservationEndAt.isAfter(now))) {
      return '예약 사용 시간이 지났습니다.';
    }
    final requestedEndAt = now.add(Duration(minutes: minutes));
    final endAt =
        reservationEndAt == null || requestedEndAt.isBefore(reservationEndAt)
        ? requestedEndAt
        : reservationEndAt;

    try {
      if (activeReservation != null) {
        await SupabaseConfig.client
            .from('reservations')
            .update({'reserved_end_at': endAt.toIso8601String()})
            .eq('id', activeReservation.reservationId);
        final index = reservations.indexWhere(
          (reservation) =>
              reservation.reservationId == activeReservation.reservationId,
        );
        if (index != -1) {
          reservations[index] = reservations[index].copyWith(
            reservedEndAt: endAt,
          );
        }
      }

      final currentUserIds = _splitMultiValue(machine.currentUserId);
      final currentUserNames = _splitMultiValue(machine.currentUserName);
      if (!currentUserIds.contains(user.userId)) {
        currentUserIds.add(user.userId);
        currentUserNames.add(user.name);
      }
      final updatedMachine = machine.copyWith(
        status: MachineStatus.using,
        currentUserId: _joinMultiValue(currentUserIds),
        currentUserName: _joinMultiValue(currentUserNames),
        startedAt: machine.startedAt ?? now,
        endAt: _latestDateTime(machine.endAt, endAt),
      );
      await _updateMachine(updatedMachine);
      _replaceLocalMachine(updatedMachine);
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
    final userActiveReservation = reservations
        .where(
          (reservation) =>
              reservation.machineId == machineId &&
              reservation.userId == user.userId &&
              reservation.status == ReservationStatus.active,
        )
        .firstOrNull;
    if (userActiveReservation == null &&
        !_splitMultiValue(machine.currentUserId).contains(user.userId)) {
      return '본인이 사용 중인 기구만 종료할 수 있습니다.';
    }

    final now = DateTime.now();
    final startedAt =
        userActiveReservation?.reservedStartAt ?? machine.startedAt ?? now;
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

    try {
      await SupabaseConfig.client
          .from('usage_logs')
          .insert(usageLog.toSupabase());

      if (userActiveReservation != null) {
        await SupabaseConfig.client
            .from('reservations')
            .update({'status': ReservationStatus.completed.name})
            .eq('id', userActiveReservation.reservationId);
        final index = reservations.indexWhere(
          (reservation) =>
              reservation.reservationId == userActiveReservation.reservationId,
        );
        if (index != -1) {
          reservations[index] = reservations[index].copyWith(
            status: ReservationStatus.completed,
          );
        }
      }

      final hasOtherActiveUsers = reservations.any(
        (reservation) =>
            reservation.machineId == machineId &&
            reservation.status == ReservationStatus.active &&
            reservation.reservationId != userActiveReservation?.reservationId,
      );
      final currentUserIds = _splitMultiValue(machine.currentUserId);
      final currentUserNames = _splitMultiValue(machine.currentUserName);
      final removeIndex = currentUserIds.indexOf(user.userId);
      if (removeIndex != -1) {
        currentUserIds.removeAt(removeIndex);
        if (removeIndex < currentUserNames.length) {
          currentUserNames.removeAt(removeIndex);
        }
      }
      final hasDirectUsers = currentUserIds.isNotEmpty;

      await _updateMachine(
        machine.copyWith(
          status: hasOtherActiveUsers || hasDirectUsers
              ? MachineStatus.reserved
              : MachineStatus.available,
          currentUserId: _joinMultiValue(currentUserIds),
          currentUserName: _joinMultiValue(currentUserNames),
          clearCurrentUser: !hasDirectUsers,
          clearTimes: !hasOtherActiveUsers && !hasDirectUsers,
        ),
      );

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

  int getAvailableUseMinutesNow(MachineModel machine) {
    if (_bypassBusinessHoursForTesting) {
      return machine.maxUseMinutes.clamp(1, 15);
    }

    final now = _koreaTime(DateTime.now());
    final closeAt = _businessCloseAt(now);
    final remainingUntilClose = closeAt.difference(now).inMinutes;
    if (remainingUntilClose <= 0 || !_startsInBusinessHours(now)) return 0;
    return [
      machine.maxUseMinutes,
      15,
      remainingUntilClose,
    ].reduce((value, element) => value < element ? value : element);
  }

  int _compareReservationsByStartTime(ReservationModel a, ReservationModel b) {
    final startComparison = (a.reservedStartAt ?? a.createdAt).compareTo(
      b.reservedStartAt ?? b.createdAt,
    );
    if (startComparison != 0) return startComparison;
    return a.createdAt.compareTo(b.createdAt);
  }

  bool _reservationOverlaps(
    ReservationModel reservation, {
    required DateTime startAt,
    required DateTime endAt,
  }) {
    final existingStartAt = reservation.reservedStartAt;
    final existingEndAt = reservation.reservedEndAt;
    if (existingStartAt == null || existingEndAt == null) return false;
    return startAt.isBefore(existingEndAt) && endAt.isAfter(existingStartAt);
  }

  List<String> _splitMultiValue(String? value) {
    if (value == null || value.isEmpty) return [];
    return value
        .split(_multiUserSeparator)
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String? _joinMultiValue(List<String> values) {
    final cleanValues = values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (cleanValues.isEmpty) return null;
    return cleanValues.join(_multiUserSeparator);
  }

  DateTime _latestDateTime(DateTime? first, DateTime second) {
    if (first == null) return second;
    return first.isAfter(second) ? first : second;
  }

  int _overlappingReservationCount(
    String machineId, {
    required DateTime startAt,
    required DateTime endAt,
  }) {
    return reservations
        .where(
          (reservation) =>
              reservation.machineId == machineId &&
              (reservation.status == ReservationStatus.waiting ||
                  reservation.status == ReservationStatus.active) &&
              _reservationOverlaps(reservation, startAt: startAt, endAt: endAt),
        )
        .length;
  }

  void _startReservationTimer() {
    _reservationTimer?.cancel();
    _reservationTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final changed = await _applyReservationWindows();
      if (changed) {
        notifyListeners();
      }
    });
  }

  Future<bool> _applyReservationWindows() async {
    if (_isApplyingReservationWindows) return false;
    _isApplyingReservationWindows = true;

    var changed = false;
    final now = DateTime.now();
    final affectedMachineIds = <String>{};

    try {
      for (var index = 0; index < reservations.length; index++) {
        final reservation = reservations[index];
        if (reservation.status != ReservationStatus.waiting &&
            reservation.status != ReservationStatus.active) {
          continue;
        }

        final startAt = reservation.reservedStartAt;
        final endAt = reservation.reservedEndAt;
        if (startAt == null || endAt == null) continue;

        if (now.isAfter(endAt)) {
          await SupabaseConfig.client
              .from('reservations')
              .update({'status': ReservationStatus.cancelled.name})
              .eq('id', reservation.reservationId);
          reservations[index] = reservation.copyWith(
            status: ReservationStatus.cancelled,
          );
          affectedMachineIds.add(reservation.machineId);
          changed = true;
          continue;
        }

        final isReservedWindow = !now.isBefore(startAt) && now.isBefore(endAt);
        if (isReservedWindow &&
            reservation.status == ReservationStatus.waiting) {
          await SupabaseConfig.client
              .from('reservations')
              .update({'status': ReservationStatus.active.name})
              .eq('id', reservation.reservationId);
          reservations[index] = reservation.copyWith(
            status: ReservationStatus.active,
          );
          affectedMachineIds.add(reservation.machineId);
          changed = true;
        }
      }

      for (final machineId in affectedMachineIds) {
        await _refreshMachineReservationState(machineId);
      }

      return changed;
    } finally {
      _isApplyingReservationWindows = false;
    }
  }

  String? _validateBusinessWindow({
    required DateTime startAt,
    required int minutes,
    required String actionName,
    bool requireFuture = false,
  }) {
    if (_bypassBusinessHoursForTesting) return null;

    final startKst = _koreaTime(startAt);
    final endKst = startKst.add(Duration(minutes: minutes));
    final openAt = _businessOpenAt(startKst);
    final closeAt = _businessCloseAt(startKst);

    if (requireFuture && startKst.isBefore(_koreaTime(DateTime.now()))) {
      return '$actionName 시간은 현재 이후여야 합니다.';
    }

    if (startKst.isBefore(openAt) || endKst.isAfter(closeAt)) {
      return '$actionName은 21:00부터 22:50 안에서만 가능합니다.';
    }

    return null;
  }

  bool _startsInBusinessHours(DateTime koreaTime) {
    final openAt = _businessOpenAt(koreaTime);
    final closeAt = _businessCloseAt(koreaTime);
    return !koreaTime.isBefore(openAt) && koreaTime.isBefore(closeAt);
  }

  DateTime _koreaTime(DateTime dateTime) {
    return dateTime.toUtc().add(const Duration(hours: 9));
  }

  DateTime _businessOpenAt(DateTime koreaTime) {
    return DateTime(koreaTime.year, koreaTime.month, koreaTime.day, 21);
  }

  DateTime _businessCloseAt(DateTime koreaTime) {
    return DateTime(koreaTime.year, koreaTime.month, koreaTime.day, 22, 50);
  }

  Future<void> _updateMachine(MachineModel machine) async {
    final values = machine.toSupabase()..remove('id');
    await SupabaseConfig.client
        .from('machines')
        .update(values)
        .eq('id', machine.machineId);
  }

  void _replaceLocalMachine(MachineModel machine) {
    final index = machines.indexWhere(
      (item) => item.machineId == machine.machineId,
    );
    if (index != -1) {
      machines[index] = machine;
    }
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
    if (machine.status == MachineStatus.repair) {
      return;
    }
    final hasActiveReservation = reservations.any(
      (reservation) =>
          reservation.machineId == machineId &&
          reservation.status == ReservationStatus.active,
    );
    final updatedMachine = machine.copyWith(
      status: hasActiveReservation
          ? MachineStatus.reserved
          : MachineStatus.available,
    );
    await _updateMachine(updatedMachine);
    final index = machines.indexWhere((item) => item.machineId == machineId);
    if (index != -1) {
      machines[index] = updatedMachine;
    }
  }
}
