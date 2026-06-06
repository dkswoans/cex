import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show RealtimeChannel, PostgresChangeEvent;

import '../config/secrets.dart';
import '../data/machine_seed_data.dart';
import '../models/machine_model.dart';
import '../models/reservation_model.dart';
import '../models/usage_log_model.dart';
import '../models/user_model.dart';
import '../services/supabase_config.dart';

enum ReservationAlertType { upcoming, ready }

class ReservationAlert {
  const ReservationAlert({
    required this.reservation,
    required this.type,
    required this.minutesUntilStart,
  });

  final ReservationModel reservation;
  final ReservationAlertType type;
  final int minutesUntilStart;

  String get key => '${reservation.reservationId}:${type.name}';
}

class GymProvider extends ChangeNotifier {
  static const bool _bypassBusinessHoursForTesting = false;
  static const String _multiUserSeparator = '|';
  static const Duration reservationAlertLeadTime = Duration(minutes: 5);

  GymProvider() {
    syncFromDatabase();
    _startReservationTimer();
    _initRealtime();
  }

  UserModel? currentUser;
  final List<MachineModel> machines = [];
  final List<ReservationModel> reservations = [];
  final List<UsageLogModel> usageLogs = [];
  bool isLoading = false;
  bool isActionLoading = false;
  String? errorMessage;
  Timer? _reservationTimer;
  bool _isApplyingReservationWindows = false;
  RealtimeChannel? _realtimeChannel;
  Timer? _realtimeDebounce;
  String? _lastReservationAlertSnapshot;

  Future<String> _runAction(Future<String> Function() action) async {
    isActionLoading = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _reservationTimer?.cancel();
    _realtimeDebounce?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> syncFromDatabase({bool showLoading = true}) async {
    if (showLoading) {
      isLoading = true;
    }
    errorMessage = null;
    if (showLoading) {
      notifyListeners();
    }

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
      debugPrint('[GymProvider] syncFromDatabase error: $error');
      errorMessage = '데이터를 불러오지 못했습니다.';
    } finally {
      if (showLoading) {
        isLoading = false;
      }
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
      role: adminUserIds.contains(userId) ? 'admin' : 'user',
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

  List<UsageLogModel> getMyUsageLogs() {
    final user = currentUser;
    if (user == null) return [];
    return usageLogs.where((log) => log.userId == user.userId).toList()
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
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

  ReservationAlert? getMyReservationAlert({DateTime? now}) {
    final user = currentUser;
    if (user == null) return null;

    final currentTime = now ?? DateTime.now();
    final activeReservations =
        reservations
            .where(
              (reservation) =>
                  reservation.userId == user.userId &&
                  (reservation.status == ReservationStatus.waiting ||
                      reservation.status == ReservationStatus.active) &&
                  reservation.reservedStartAt != null &&
                  reservation.reservedEndAt != null &&
                  currentTime.isBefore(reservation.reservedEndAt!),
            )
            .toList()
          ..sort(_compareReservationsByStartTime);

    for (final reservation in activeReservations) {
      final startAt = reservation.reservedStartAt!;
      final endAt = reservation.reservedEndAt!;
      final isReady =
          reservation.status == ReservationStatus.active ||
          (!currentTime.isBefore(startAt) && currentTime.isBefore(endAt));
      if (isReady) {
        return ReservationAlert(
          reservation: reservation,
          type: ReservationAlertType.ready,
          minutesUntilStart: 0,
        );
      }
    }

    for (final reservation in activeReservations) {
      final startAt = reservation.reservedStartAt!;
      final timeUntilStart = startAt.difference(currentTime);
      if (timeUntilStart.isNegative ||
          timeUntilStart > reservationAlertLeadTime) {
        continue;
      }

      return ReservationAlert(
        reservation: reservation,
        type: ReservationAlertType.upcoming,
        minutesUntilStart: _ceilPositiveMinutes(timeUntilStart),
      );
    }

    return null;
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

  MachineModel? getMachineCurrentlyUsedByMe() {
    final user = currentUser;
    if (user == null) return null;
    final activeReservations =
        reservations
            .where(
              (reservation) =>
                  reservation.userId == user.userId &&
                  reservation.status == ReservationStatus.active,
            )
            .toList()
          ..sort(_compareReservationsByStartTime);

    if (activeReservations.isNotEmpty) {
      final reservation = activeReservations.first;
      final machine = getMachineById(reservation.machineId);
      return machine.copyWith(
        status: MachineStatus.using,
        startedAt: reservation.reservedStartAt ?? machine.startedAt,
        endAt: reservation.reservedEndAt ?? machine.endAt,
      );
    }

    for (final machine in machines) {
      final isDirectUser = _splitMultiValue(
        machine.currentUserId,
      ).any((value) => _baseUserId(value) == user.userId);
      if (isDirectUser) return machine;
    }
    return null;
  }

  int getWeeklyUsageMinutes() {
    final user = currentUser;
    if (user == null) return 0;
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return usageLogs
        .where(
          (log) => log.userId == user.userId && log.endedAt.isAfter(weekAgo),
        )
        .fold(0, (sum, log) => sum + log.usedMinutes);
  }

  int getWeeklySessionCount() {
    final user = currentUser;
    if (user == null) return 0;
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return usageLogs
        .where(
          (log) => log.userId == user.userId && log.endedAt.isAfter(weekAgo),
        )
        .length;
  }

  List<MapEntry<String, int>> getTopMachinesByUsage(int n) {
    final user = currentUser;
    if (user == null) return [];
    final Map<String, int> totals = {};
    for (final log in usageLogs.where((log) => log.userId == user.userId)) {
      totals[log.machineName] =
          (totals[log.machineName] ?? 0) + log.usedMinutes;
    }
    return (totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .take(n)
        .toList();
  }

  List<String> getMachineVariants(String machineId) {
    return switch (machineId) {
      'dumbbell' => const [
        '3kg',
        '4kg',
        '5kg',
        '6kg',
        '7kg',
        '8kg',
        '9kg',
        '10kg',
        '11kg',
        '12kg',
        '13kg',
        '14kg',
        '15kg',
        '16kg',
        '17kg',
        '18kg',
        '19kg',
        '20kg',
      ],
      'barbell' => const [
        '일자바 10kg',
        '일자바 15kg',
        '일자바 20kg',
        '일자바 25kg',
        '일자바 30kg',
        '이지바 10kg',
        '이지바 15kg',
        '이지바 20kg',
        '이지바 25kg',
        '이지바 30kg',
      ],
      _ => const [],
    };
  }

  bool machineUsesVariants(String machineId) {
    return getMachineVariants(machineId).isNotEmpty;
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
              _splitMultiValue(
                machine.currentUserId,
              ).any((value) => _baseUserId(value) == user.userId),
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
      final baseUserId = _baseUserId(userId);
      if (result.any((reservation) => reservation.userId == baseUserId)) {
        continue;
      }
      result.add(
        ReservationModel(
          reservationId: '${machineId}_${userId}_direct',
          machineId: machine.machineId,
          machineName: machine.name,
          userId: baseUserId,
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
    return getMachineById(machineId).maxUseMinutes;
  }

  int getMaxReservationMinutesForMachine(String machineId) {
    return getMachineById(machineId).maxUseMinutes;
  }

  bool hasAvailableUnitNow(String machineId, {String? variantLabel}) {
    final now = DateTime.now();
    final capacity = getMachineCapacity(machineId);

    final reservationCount = _overlappingReservationCount(
      machineId,
      startAt: now,
      endAt: now.add(const Duration(minutes: 1)),
      variantLabel: variantLabel,
    );
    if (reservationCount >= capacity) return false;

    final machine = getMachineById(machineId);
    final currentIds = _splitMultiValue(machine.currentUserId);
    final directCount = variantLabel != null
        ? currentIds.where((id) => id.endsWith('@$variantLabel')).length
        : currentIds.length;

    return directCount < capacity;
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
    String? variantLabel,
  }) => _runAction(() async {
    final user = currentUser;
    if (user == null) return '로그인이 필요합니다.';
    final machine = getMachineById(machineId);
    if (machineUsesVariants(machineId) &&
        (variantLabel == null || variantLabel.isEmpty)) {
      return '종류를 선택해 주세요.';
    }
    final maxMinutes = getMaxReservationMinutesForMachine(machineId);
    if (minutes < 1 || minutes > maxMinutes) {
      return '예약 시간은 1분부터 $maxMinutes분까지 가능합니다.';
    }

    final reservationError = _validateBusinessWindow(
      startAt: startAt,
      minutes: minutes,
      actionName: '예약',
      requireFuture: true,
      enforceBusinessHours: false,
    );
    if (reservationError != null) return reservationError;

    await _applyReservationWindows();
    if (machine.status == MachineStatus.repair) {
      return '점검 중인 기구는 예약할 수 없습니다.';
    }

    final alreadyReserved = getMyReservations().any(
      (reservation) =>
          reservation.machineId == machineId &&
          (!machineUsesVariants(machineId) ||
              _reservationMatchesVariant(reservation, variantLabel)),
    );
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
      variantLabel: variantLabel,
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
      machineName: _machineDisplayName(machine.name, variantLabel),
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
      debugPrint('[GymProvider] reserveMachine error: $error');
      return '예약에 실패했습니다.';
    }
  });

  Future<String> cancelReservation(String reservationId) =>
      _runAction(() async {
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
          debugPrint('[GymProvider] cancelReservation error: $error');
          return '예약 취소에 실패했습니다.';
        }
      });

  Future<String> startUsingMachine(
    String machineId, {
    required int minutes,
    String? variantLabel,
  }) => _runAction(() async {
    final user = currentUser;
    await _applyReservationWindows();
    if (user == null) return '로그인이 필요합니다.';

    final machine = getMachineById(machineId);
    if (machineUsesVariants(machineId) &&
        (variantLabel == null || variantLabel.isEmpty)) {
      return '종류를 선택해 주세요.';
    }
    final maxMinutes = getMaxUseMinutesForMachine(machineId);
    final activeReservation = reservations
        .where(
          (reservation) =>
              reservation.machineId == machineId &&
              reservation.userId == user.userId &&
              reservation.status == ReservationStatus.active &&
              _reservationMatchesVariant(reservation, variantLabel),
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
              _splitMultiValue(
                item.currentUserId,
              ).any((value) => _baseUserId(value) == user.userId) &&
              item.machineId != machineId,
        );
    if (usingOther) return '이미 다른 기구를 사용 중입니다.';

    if (activeReservation == null &&
        !hasAvailableUnitNow(machineId, variantLabel: variantLabel)) {
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
      final usageUserId = _usageUserId(user.userId, variantLabel);
      if (!currentUserIds.contains(usageUserId)) {
        currentUserIds.add(usageUserId);
        currentUserNames.add(_usageUserName(user.name, variantLabel));
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
      debugPrint('[GymProvider] startUsingMachine error: $error');
      return '사용 시작에 실패했습니다.';
    }
  });

  Future<String> finishUsingMachine(String machineId) => _runAction(() async {
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
        !_splitMultiValue(
          machine.currentUserId,
        ).any((value) => _baseUserId(value) == user.userId)) {
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
      final removeIndex = currentUserIds.indexWhere(
        (value) => _baseUserId(value) == user.userId,
      );
      if (removeIndex != -1) {
        currentUserIds.removeAt(removeIndex);
        if (removeIndex < currentUserNames.length) {
          currentUserNames.removeAt(removeIndex);
        }
      }
      final hasDirectUsers = currentUserIds.isNotEmpty;

      final newStatus = hasDirectUsers
          ? MachineStatus.using
          : hasOtherActiveUsers
          ? MachineStatus.reserved
          : MachineStatus.available;

      await _updateMachine(
        machine.copyWith(
          status: newStatus,
          currentUserId: _joinMultiValue(currentUserIds),
          currentUserName: _joinMultiValue(currentUserNames),
          clearCurrentUser: !hasDirectUsers,
          clearTimes: !hasOtherActiveUsers && !hasDirectUsers,
        ),
      );

      await syncFromDatabase();
      return '사용을 종료했습니다.';
    } catch (error) {
      debugPrint('[GymProvider] finishUsingMachine error: $error');
      return '사용 종료에 실패했습니다.';
    }
  });

  Future<String> toggleRepairStatus(String machineId) => _runAction(() async {
    final machine = getMachineById(machineId);
    final goingToRepair = machine.status != MachineStatus.repair;
    try {
      if (goingToRepair) {
        final affected = reservations
            .where(
              (r) =>
                  r.machineId == machineId &&
                  (r.status == ReservationStatus.active ||
                      r.status == ReservationStatus.waiting),
            )
            .toList();
        for (final r in affected) {
          await SupabaseConfig.client
              .from('reservations')
              .update({'status': ReservationStatus.cancelled.name})
              .eq('id', r.reservationId);
        }
      }
      await _updateMachine(
        machine.copyWith(
          status: goingToRepair
              ? MachineStatus.repair
              : MachineStatus.available,
          clearCurrentUser: goingToRepair,
          clearTimes: goingToRepair,
        ),
      );
      await syncFromDatabase();
      return goingToRepair ? '점검 상태로 변경되었습니다.' : '점검이 해제되었습니다.';
    } catch (error) {
      debugPrint('[GymProvider] toggleRepairStatus error: $error');
      return '상태 변경에 실패했습니다.';
    }
  });

  Future<String> updateMachineSettings(
    String machineId, {
    int? maxUseMinutes,
    double? mapX,
    double? mapY,
  }) => _runAction(() async {
    final machine = getMachineById(machineId);
    try {
      await _updateMachine(
        machine.copyWith(maxUseMinutes: maxUseMinutes, mapX: mapX, mapY: mapY),
      );
      await syncFromDatabase();
      return '설정이 저장되었습니다.';
    } catch (error) {
      debugPrint('[GymProvider] updateMachineSettings error: $error');
      return '저장에 실패했습니다.';
    }
  });

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
      return machine.maxUseMinutes;
    }

    final now = _koreaTime(DateTime.now());
    final closeAt = _businessCloseAt(now);
    final remainingUntilClose = closeAt.difference(now).inMinutes;
    if (remainingUntilClose <= 0 || !_startsInBusinessHours(now)) return 0;
    return machine.maxUseMinutes < remainingUntilClose
        ? machine.maxUseMinutes
        : remainingUntilClose;
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

  bool _reservationMatchesVariant(
    ReservationModel reservation,
    String? variantLabel,
  ) {
    if (variantLabel == null || variantLabel.isEmpty) return true;
    return reservation.machineName.endsWith(' $variantLabel');
  }

  String _machineDisplayName(String machineName, String? variantLabel) {
    if (variantLabel == null || variantLabel.isEmpty) return machineName;
    return '$machineName $variantLabel';
  }

  String _usageUserId(String userId, String? variantLabel) {
    if (variantLabel == null || variantLabel.isEmpty) return userId;
    return '$userId@$variantLabel';
  }

  String _usageUserName(String userName, String? variantLabel) {
    if (variantLabel == null || variantLabel.isEmpty) return userName;
    return '$userName · $variantLabel';
  }

  String _baseUserId(String value) {
    return value.split('@').first;
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

  int _ceilPositiveMinutes(Duration duration) {
    if (duration.inSeconds <= 0) return 0;
    return (duration.inSeconds / Duration.secondsPerMinute).ceil();
  }

  int _overlappingReservationCount(
    String machineId, {
    required DateTime startAt,
    required DateTime endAt,
    String? variantLabel,
  }) {
    return reservations
        .where(
          (reservation) =>
              reservation.machineId == machineId &&
              (reservation.status == ReservationStatus.waiting ||
                  reservation.status == ReservationStatus.active) &&
              _reservationMatchesVariant(reservation, variantLabel) &&
              _reservationOverlaps(reservation, startAt: startAt, endAt: endAt),
        )
        .length;
  }

  void _startReservationTimer() {
    _reservationTimer?.cancel();
    _reservationTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final changed = await _applyReservationWindows();
      final alertSnapshot = _reservationAlertSnapshot(getMyReservationAlert());
      final alertChanged = alertSnapshot != _lastReservationAlertSnapshot;
      _lastReservationAlertSnapshot = alertSnapshot;
      if (changed || alertChanged) {
        notifyListeners();
      }
    });
  }

  void _initRealtime() {
    final channel = SupabaseConfig.client.channel('gym_realtime');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'machines',
          callback: (_) => _scheduleRealtimeSync(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reservations',
          callback: (_) => _scheduleRealtimeSync(),
        )
        .subscribe();
    _realtimeChannel = channel;
  }

  void _scheduleRealtimeSync() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(
      const Duration(milliseconds: 800),
      () => syncFromDatabase(showLoading: false),
    );
  }

  String? _reservationAlertSnapshot(ReservationAlert? alert) {
    if (alert == null) return null;
    return '${alert.key}:${alert.minutesUntilStart}';
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
    bool enforceBusinessHours = true,
  }) {
    if (_bypassBusinessHoursForTesting) return null;

    final startKst = _koreaTime(startAt);
    final endKst = startKst.add(Duration(minutes: minutes));
    final openAt = _businessOpenAt(startKst);
    final closeAt = _businessCloseAt(startKst);

    if (requireFuture && startKst.isBefore(_koreaTime(DateTime.now()))) {
      return '$actionName 시간은 현재 이후여야 합니다.';
    }

    if (!enforceBusinessHours) return null;

    if (startKst.isBefore(openAt) || endKst.isAfter(closeAt)) {
      return '$actionName은 21:00부터 23:00 안에서만 가능합니다.';
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
    return DateTime(koreaTime.year, koreaTime.month, koreaTime.day, 23);
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
    final hasDirectUsers = _splitMultiValue(machine.currentUserId).isNotEmpty;
    final activeReservations =
        reservations
            .where(
              (reservation) =>
                  reservation.machineId == machineId &&
                  reservation.status == ReservationStatus.active,
            )
            .toList()
          ..sort(_compareReservationsByStartTime);
    final hasActiveReservation = activeReservations.isNotEmpty;
    final newStatus = hasDirectUsers
        ? MachineStatus.using
        : hasActiveReservation
        ? MachineStatus.reserved
        : MachineStatus.available;
    DateTime? activeStartedAt;
    DateTime? activeEndAt;
    for (final reservation in activeReservations) {
      final startAt = reservation.reservedStartAt;
      if (startAt != null &&
          (activeStartedAt == null || startAt.isBefore(activeStartedAt))) {
        activeStartedAt = startAt;
      }
      final endAt = reservation.reservedEndAt;
      if (endAt != null &&
          (activeEndAt == null || endAt.isAfter(activeEndAt))) {
        activeEndAt = endAt;
      }
    }
    final updatedMachine = machine.copyWith(
      status: newStatus,
      startedAt: hasDirectUsers ? machine.startedAt : activeStartedAt,
      endAt: hasDirectUsers ? machine.endAt : activeEndAt,
      clearTimes: !hasDirectUsers && !hasActiveReservation,
    );
    await _updateMachine(updatedMachine);
    final index = machines.indexWhere((item) => item.machineId == machineId);
    if (index != -1) {
      machines[index] = updatedMachine;
    }
  }
}
