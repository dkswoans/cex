import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/machine_model.dart';
import '../models/reservation_model.dart';
import '../providers/gym_provider.dart';
import '../utils/status_utils.dart';
import '../utils/time_utils.dart';
import '../widgets/app_design.dart';
import '../widgets/wobbly_card.dart';
import 'machine_detail_page.dart';

class StatusPage extends StatelessWidget {
  const StatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GymProvider>(
      builder: (context, provider, _) {
        final snapshot = _GymStatusSnapshot(provider);
        final popularMachines = snapshot.todayPopularMachines;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: const Text('현황'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: '새로고침',
                onPressed: provider.isLoading
                    ? null
                    : () async {
                        await provider.syncFromDatabase();
                        if (!context.mounted) return;
                        if (provider.errorMessage != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(provider.errorMessage!)),
                          );
                        }
                      },
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: provider.syncFromDatabase,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              children: [
                _CongestionPanel(snapshot: snapshot),
                const SizedBox(height: 14),
                _MetricGrid(snapshot: snapshot),
                const SizedBox(height: 18),
                const _StatusSectionTitle('오늘 인기 기구 TOP 3'),
                if (popularMachines.isEmpty)
                  const _StatusEmptyPanel(text: '오늘 이용/예약 기록이 아직 없습니다.')
                else
                  ...popularMachines.asMap().entries.map(
                    (entry) => _PopularMachineTile(
                      rank: entry.key + 1,
                      item: entry.value,
                      onTap: entry.value.machine == null
                          ? null
                          : () => _openDetail(context, entry.value.machine!),
                    ),
                  ),
                const SizedBox(height: 18),
                const _StatusSectionTitle('시간대별 혼잡도'),
                _HourlyCongestionPanel(snapshot: snapshot),
                const SizedBox(height: 18),
                const _StatusSectionTitle('러닝/사이클 자리'),
                _CardioCapacityRow(snapshot: snapshot),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openDetail(BuildContext context, MachineModel machine) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MachineDetailPage(machineId: machine.machineId),
      ),
    );
  }
}

class _GymStatusSnapshot {
  _GymStatusSnapshot(this.provider)
    : now = DateTime.now(),
      activeUnits = _activeUnits(provider),
      totalUnits = _totalUnits(provider),
      waitingTotal = _waitingTotal(provider),
      repairCount = provider.machines
          .where((machine) => machine.status == MachineStatus.repair)
          .length;

  final GymProvider provider;
  final DateTime now;
  final int activeUnits;
  final int totalUnits;
  final int waitingTotal;
  final int repairCount;

  double get congestionRatio {
    if (totalUnits == 0) return 1;
    return ((activeUnits + waitingTotal * 0.5) / totalUnits).clamp(0, 1);
  }

  String get congestionLabel {
    final ratio = congestionRatio;
    if (ratio < 0.35) return '여유';
    if (ratio < 0.7) return '보통';
    return '혼잡';
  }

  Color get congestionColor {
    final ratio = congestionRatio;
    if (ratio < 0.35) return greenColor;
    if (ratio < 0.7) return amberColor;
    return redColor;
  }

  String get congestionMessage {
    return switch (congestionLabel) {
      '여유' => '지금은 바로 쓸 수 있는 기구가 꽤 있습니다.',
      '보통' => '몇몇 기구는 대기가 있으니 시간표를 확인하세요.',
      _ => '대기와 사용 중인 기구가 많습니다.',
    };
  }

  List<_PopularMachine> get todayPopularMachines {
    return _todayPopularMachines(provider, now);
  }

  List<_HourlyCongestion> get hourlyCongestion {
    return _hourlyCongestion(provider, now, totalUnits);
  }

  _HourlySlotDetails detailsFor(_HourlyCongestion slot) {
    return _slotDetails(provider, slot.startAt, slot.endAt, now);
  }

  List<MachineModel> get cardioMachines {
    return provider.machines
        .where(
          (machine) =>
              machine.machineId == 'treadmill' || machine.machineId == 'cycle',
        )
        .toList();
  }

  List<_UsingMachine> get usingMachines {
    final result =
        provider.machines
            .where(
              (machine) =>
                  machine.machineId != 'treadmill' &&
                  machine.status != MachineStatus.repair,
            )
            .map((machine) {
              final activeCount = provider.getActiveCount(machine.machineId);
              return _UsingMachine(
                machine: machine,
                activeCount: activeCount,
                capacity: provider.getMachineCapacity(machine.machineId),
                users: provider.getCurrentUsersByMachine(machine.machineId),
              );
            })
            .where((entry) => entry.activeCount > 0)
            .toList()
          ..sort((a, b) {
            final activeCompare = b.activeCount.compareTo(a.activeCount);
            if (activeCompare != 0) return activeCompare;
            return a.machine.name.compareTo(b.machine.name);
          });
    return result;
  }

  int remainingUnits(MachineModel machine) {
    if (machine.status == MachineStatus.repair) return 0;
    final capacity = provider.getMachineCapacity(machine.machineId);
    final active = provider.getActiveCount(machine.machineId);
    final remaining = capacity - active;
    return remaining < 0 ? 0 : remaining;
  }

  static int _totalUnits(GymProvider provider) {
    return provider.machines
        .where(
          (machine) =>
              machine.machineId != 'treadmill' &&
              machine.status != MachineStatus.repair,
        )
        .fold(
          0,
          (sum, machine) =>
              sum + provider.getMachineCapacity(machine.machineId),
        );
  }

  static int _activeUnits(GymProvider provider) {
    return provider.machines
        .where(
          (machine) =>
              machine.machineId != 'treadmill' &&
              machine.status != MachineStatus.repair,
        )
        .fold(0, (sum, machine) {
          final capacity = provider.getMachineCapacity(machine.machineId);
          final active = provider.getActiveCount(machine.machineId);
          return sum + (active > capacity ? capacity : active);
        });
  }

  static int _waitingTotal(GymProvider provider) {
    return provider.machines.fold(
      0,
      (sum, machine) => sum + provider.getWaitingCount(machine.machineId),
    );
  }

  static List<_PopularMachine> _todayPopularMachines(
    GymProvider provider,
    DateTime now,
  ) {
    final activityCounts = <String, int>{};
    final totalMinutes = <String, int>{};
    final names = <String, String>{};

    void addActivity(String machineId, String machineName, int minutes) {
      activityCounts[machineId] = (activityCounts[machineId] ?? 0) + 1;
      totalMinutes[machineId] = (totalMinutes[machineId] ?? 0) + minutes;
      names[machineId] = machineName;
    }

    for (final log in provider.usageLogs) {
      if (!_isSameKoreaDay(log.endedAt, now)) continue;
      final machine = _machineForId(provider, log.machineId);
      addActivity(
        log.machineId,
        machine?.name ?? log.machineName,
        log.usedMinutes,
      );
    }

    for (final reservation in provider.reservations) {
      if (!_isLiveReservation(reservation)) continue;
      final startAt = reservation.reservedStartAt;
      final endAt = reservation.reservedEndAt;
      if (startAt == null || endAt == null) continue;
      if (!_isSameKoreaDay(startAt, now)) continue;
      final minutes = endAt.difference(startAt).inMinutes;
      final machine = _machineForId(provider, reservation.machineId);
      addActivity(
        reservation.machineId,
        machine?.name ?? reservation.machineName,
        minutes < 1 ? 0 : minutes,
      );
    }

    final result =
        activityCounts.entries.map((entry) {
          final machine = _machineForId(provider, entry.key);
          return _PopularMachine(
            machineName: machine?.name ?? names[entry.key] ?? entry.key,
            activityCount: entry.value,
            totalMinutes: totalMinutes[entry.key] ?? 0,
            machine: machine,
          );
        }).toList()..sort((a, b) {
          final countCompare = b.activityCount.compareTo(a.activityCount);
          if (countCompare != 0) return countCompare;
          return b.totalMinutes.compareTo(a.totalMinutes);
        });

    return result.take(3).toList();
  }

  static List<_HourlyCongestion> _hourlyCongestion(
    GymProvider provider,
    DateTime now,
    int capacity,
  ) {
    final koreaNow = _koreaTime(now);
    const slots = [(21, 0), (21, 30), (22, 0), (22, 30)];

    return slots.map((slot) {
      final startAt = _dateTimeFromKoreaClock(
        koreaNow.year,
        koreaNow.month,
        koreaNow.day,
        slot.$1,
        slot.$2,
      );
      final endAt = startAt.add(const Duration(minutes: 30));
      final load =
          _reservationLoadForSlot(provider, startAt, endAt) +
          _directLoadForSlot(provider, startAt, endAt) +
          _usageLogLoadForSlot(provider, startAt, endAt, now);
      final ratio = capacity == 0
          ? 0.0
          : (load / capacity).clamp(0.0, 1.0).toDouble();
      final level = _congestionLevel(ratio);
      return _HourlyCongestion(
        timeLabel:
            '${slot.$1.toString().padLeft(2, '0')}:${slot.$2.toString().padLeft(2, '0')}',
        startAt: startAt,
        endAt: endAt,
        load: load,
        capacity: capacity,
        ratio: ratio,
        statusLabel: level.$1,
        color: level.$2,
      );
    }).toList();
  }

  static _HourlySlotDetails _slotDetails(
    GymProvider provider,
    DateTime startAt,
    DateTime endAt,
    DateTime now,
  ) {
    final reservedEntries = <_SlotDetailEntry>[];
    final useEntries = <_SlotDetailEntry>[];
    final activeKeys = <String>{};

    final slotReservations =
        provider.reservations.where((reservation) {
          if (!_isDashboardMachine(reservation.machineId)) return false;
          if (!_isLiveReservation(reservation)) return false;
          final reservedStartAt = reservation.reservedStartAt;
          final reservedEndAt = reservation.reservedEndAt;
          if (reservedStartAt == null || reservedEndAt == null) {
            return false;
          }
          return _overlaps(reservedStartAt, reservedEndAt, startAt, endAt);
        }).toList()..sort(
          (a, b) => (a.reservedStartAt ?? a.createdAt).compareTo(
            b.reservedStartAt ?? b.createdAt,
          ),
        );

    for (final reservation in slotReservations) {
      final machine = _machineForId(provider, reservation.machineId);
      final title = machine?.name ?? reservation.machineName;
      final subtitle = _reservationSlotSubtitle(reservation, machine);
      if (reservation.status == ReservationStatus.active) {
        activeKeys.add('${reservation.machineId}:${reservation.userId}');
        useEntries.add(
          _SlotDetailEntry(
            title: title,
            subtitle: subtitle,
            badge: '사용 중',
            color: redColor,
            machine: machine,
          ),
        );
      } else {
        reservedEntries.add(
          _SlotDetailEntry(
            title: title,
            subtitle: subtitle,
            badge: '예약',
            color: amberColor,
            machine: machine,
          ),
        );
      }
    }

    for (final machine in provider.machines) {
      if (!_isDashboardMachine(machine.machineId)) continue;
      if (machine.status == MachineStatus.repair) continue;
      if (!_directUsageOverlaps(machine, startAt, endAt)) continue;

      final userIds = _splitMultiValue(machine.currentUserId);
      final userNames = _splitMultiValue(machine.currentUserName);
      for (var index = 0; index < userIds.length; index++) {
        final baseUserId = _baseUserId(userIds[index]);
        if (activeKeys.contains('${machine.machineId}:$baseUserId')) continue;
        final userName = index < userNames.length
            ? userNames[index]
            : baseUserId;
        useEntries.add(
          _SlotDetailEntry(
            title: machine.name,
            subtitle:
                '$userName · ${formatTimeRange(machine.startedAt, machine.endAt)}',
            badge: '사용 중',
            color: redColor,
            machine: machine,
          ),
        );
      }
    }

    final usageLogs = provider.usageLogs.where((log) {
      if (!_isDashboardMachine(log.machineId)) return false;
      if (!log.endedAt.isBefore(now)) return false;
      return _overlaps(log.startedAt, log.endedAt, startAt, endAt);
    }).toList()..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    for (final log in usageLogs) {
      final machine = _machineForId(provider, log.machineId);
      useEntries.add(
        _SlotDetailEntry(
          title: machine?.name ?? log.machineName,
          subtitle:
              '${log.userName} · ${formatTimeRange(log.startedAt, log.endedAt)}',
          badge: '사용 기록',
          color: blueColor,
          machine: machine,
        ),
      );
    }

    return _HourlySlotDetails(
      reservedEntries: reservedEntries,
      useEntries: useEntries,
    );
  }

  static int _reservationLoadForSlot(
    GymProvider provider,
    DateTime startAt,
    DateTime endAt,
  ) {
    return provider.reservations.where((reservation) {
      if (!_isDashboardMachine(reservation.machineId)) return false;
      if (!_isLiveReservation(reservation)) return false;
      final reservedStartAt = reservation.reservedStartAt;
      final reservedEndAt = reservation.reservedEndAt;
      if (reservedStartAt == null || reservedEndAt == null) return false;
      return _overlaps(reservedStartAt, reservedEndAt, startAt, endAt);
    }).length;
  }

  static int _directLoadForSlot(
    GymProvider provider,
    DateTime startAt,
    DateTime endAt,
  ) {
    return provider.machines
        .where((machine) => _isDashboardMachine(machine.machineId))
        .where((machine) => machine.status != MachineStatus.repair)
        .where((machine) => _directUsageOverlaps(machine, startAt, endAt))
        .fold(0, (sum, machine) => sum + _currentUserCount(machine));
  }

  static int _usageLogLoadForSlot(
    GymProvider provider,
    DateTime startAt,
    DateTime endAt,
    DateTime now,
  ) {
    return provider.usageLogs.where((log) {
      if (!_isDashboardMachine(log.machineId)) return false;
      if (!log.endedAt.isBefore(now)) return false;
      return _overlaps(log.startedAt, log.endedAt, startAt, endAt);
    }).length;
  }

  static bool _isLiveReservation(ReservationModel reservation) {
    return reservation.status == ReservationStatus.waiting ||
        reservation.status == ReservationStatus.active;
  }

  static bool _isDashboardMachine(String machineId) {
    return machineId != 'treadmill';
  }

  static bool _directUsageOverlaps(
    MachineModel machine,
    DateTime startAt,
    DateTime endAt,
  ) {
    if (_currentUserCount(machine) == 0) return false;
    final machineEndAt = machine.endAt;
    if (machineEndAt != null && !startAt.isBefore(machineEndAt)) return false;
    final machineStartAt = machine.startedAt;
    if (machineStartAt != null && !endAt.isAfter(machineStartAt)) return false;
    return true;
  }

  static int _currentUserCount(MachineModel machine) {
    final currentUserId = machine.currentUserId;
    if (currentUserId == null || currentUserId.trim().isEmpty) return 0;
    return currentUserId
        .split('|')
        .where((item) => item.trim().isNotEmpty)
        .length;
  }

  static List<String> _splitMultiValue(String? value) {
    if (value == null || value.isEmpty) return [];
    return value
        .split('|')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String _baseUserId(String value) {
    return value.split('@').first;
  }

  static String _reservationSlotSubtitle(
    ReservationModel reservation,
    MachineModel? machine,
  ) {
    final range = formatTimeRange(
      reservation.reservedStartAt,
      reservation.reservedEndAt,
    );
    if (machine == null || reservation.machineName == machine.name) {
      return '${reservation.userName} · $range';
    }
    return '${reservation.userName} · ${reservation.machineName} · $range';
  }

  static bool _overlaps(
    DateTime firstStartAt,
    DateTime firstEndAt,
    DateTime secondStartAt,
    DateTime secondEndAt,
  ) {
    return firstStartAt.isBefore(secondEndAt) &&
        firstEndAt.isAfter(secondStartAt);
  }

  static bool _isSameKoreaDay(DateTime dateTime, DateTime base) {
    final koreaDateTime = _koreaTime(dateTime);
    final koreaBase = _koreaTime(base);
    return koreaDateTime.year == koreaBase.year &&
        koreaDateTime.month == koreaBase.month &&
        koreaDateTime.day == koreaBase.day;
  }

  static DateTime _koreaTime(DateTime dateTime) {
    return dateTime.toUtc().add(const Duration(hours: 9));
  }

  static DateTime _dateTimeFromKoreaClock(
    int year,
    int month,
    int day,
    int hour,
    int minute,
  ) {
    return DateTime.utc(year, month, day, hour - 9, minute);
  }

  static (String, Color) _congestionLevel(double ratio) {
    if (ratio < 0.35) return ('여유', greenColor);
    if (ratio < 0.7) return ('보통', amberColor);
    return ('혼잡', redColor);
  }

  static MachineModel? _machineForId(GymProvider provider, String machineId) {
    for (final machine in provider.machines) {
      if (machine.machineId == machineId) return machine;
    }
    return null;
  }
}

class _PopularMachine {
  const _PopularMachine({
    required this.machineName,
    required this.activityCount,
    required this.totalMinutes,
    required this.machine,
  });

  final String machineName;
  final int activityCount;
  final int totalMinutes;
  final MachineModel? machine;
}

class _HourlyCongestion {
  const _HourlyCongestion({
    required this.timeLabel,
    required this.startAt,
    required this.endAt,
    required this.load,
    required this.capacity,
    required this.ratio,
    required this.statusLabel,
    required this.color,
  });

  final String timeLabel;
  final DateTime startAt;
  final DateTime endAt;
  final int load;
  final int capacity;
  final double ratio;
  final String statusLabel;
  final Color color;
}

class _HourlySlotDetails {
  const _HourlySlotDetails({
    required this.reservedEntries,
    required this.useEntries,
  });

  final List<_SlotDetailEntry> reservedEntries;
  final List<_SlotDetailEntry> useEntries;

  bool get isEmpty => reservedEntries.isEmpty && useEntries.isEmpty;
}

class _SlotDetailEntry {
  const _SlotDetailEntry({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.color,
    required this.machine,
  });

  final String title;
  final String subtitle;
  final String badge;
  final Color color;
  final MachineModel? machine;
}

class _UsingMachine {
  const _UsingMachine({
    required this.machine,
    required this.activeCount,
    required this.capacity,
    required this.users,
  });

  final MachineModel machine;
  final int activeCount;
  final int capacity;
  final List<ReservationModel> users;
}

class _StatusWobblyCard extends StatelessWidget {
  const _StatusWobblyCard({
    required this.seed,
    required this.child,
    this.fillColor = surfaceColor,
    this.padding = const EdgeInsets.all(14),
    this.margin = const EdgeInsets.symmetric(vertical: 4),
    this.shadows,
    this.rotation,
  });

  final String seed;
  final Widget child;
  final Color fillColor;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final List<BoxShadow>? shadows;
  final double? rotation;

  @override
  Widget build(BuildContext context) {
    final angle =
        rotation ?? (math.Random(seed.hashCode).nextDouble() - 0.5) * 0.045;
    return Transform.rotate(
      angle: angle,
      child: WobblyCard(
        seed: seed,
        shadows: shadows ?? randomShadows(seed),
        fillColor: fillColor,
        padding: padding,
        margin: margin,
        child: child,
      ),
    );
  }
}

class _StatusSectionTitle extends StatelessWidget {
  const _StatusSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final rng = math.Random(text.hashCode);
    final angle = (rng.nextDouble() - 0.5) * 0.11;
    const colors = [textColor, blueColor, redColor, amberColor];
    final color = colors[rng.nextInt(colors.length)];

    return Padding(
      padding: const EdgeInsets.only(bottom: 3, top: 4),
      child: Transform.rotate(
        alignment: Alignment.centerLeft,
        angle: angle,
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: 0,
            shadows: const [
              Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusEmptyPanel extends StatelessWidget {
  const _StatusEmptyPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _StatusWobblyCard(
      seed: 'empty_$text',
      child: Center(child: Text(text, style: AppTextStyles.empty)),
    );
  }
}

class _CongestionPanel extends StatelessWidget {
  const _CongestionPanel({required this.snapshot});

  final _GymStatusSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _StatusWobblyCard(
      seed: 'status_congestion',
      rotation: -0.012,
      padding: const EdgeInsets.all(16),
      shadows: const [
        BoxShadow(color: blueColor, offset: Offset(5, 5), blurRadius: 0),
        BoxShadow(color: redColor, offset: Offset(-2, -2), blurRadius: 0),
      ],
      child: Row(
        children: [
          Container(
            width: 82,
            height: 82,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: snapshot.congestionColor,
              border: Border.all(color: borderColor, width: 4),
            ),
            child: Text(
              snapshot.congestionLabel,
              style: const TextStyle(
                color: borderColor,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '오늘 헬스장 상태',
                  style: TextStyle(
                    color: bgColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        offset: Offset(2, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  snapshot.congestionMessage,
                  style: const TextStyle(
                    color: borderColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PopularMachineTile extends StatelessWidget {
  const _PopularMachineTile({
    required this.rank,
    required this.item,
    required this.onTap,
  });

  final int rank;
  final _PopularMachine item;
  final VoidCallback? onTap;

  static const _rankColors = [redColor, blueColor, greenColor];

  @override
  Widget build(BuildContext context) {
    final rankColor = rank <= _rankColors.length
        ? _rankColors[rank - 1]
        : amberColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: GestureDetector(
        onTap: onTap,
        child: _StatusWobblyCard(
          seed: 'popular_${rank}_${item.machineName}',
          fillColor: Color.lerp(rankColor, bgColor, 0.32)!,
          padding: const EdgeInsets.all(12),
          margin: EdgeInsets.zero,
          shadows: chipShadows('popular_${rank}_${item.machineName}'),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rankColor,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: borderColor, width: 3),
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: borderColor,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.machineName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.itemTitle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '오늘 ${item.activityCount}건 · ${formatRemainingMinutes(item.totalMinutes)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label,
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right, color: textColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _HourlyCongestionPanel extends StatelessWidget {
  const _HourlyCongestionPanel({required this.snapshot});

  final _GymStatusSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final items = snapshot.hourlyCongestion;
    final navigator = Navigator.of(context);
    return _StatusWobblyCard(
      seed: 'hourly_congestion',
      padding: const EdgeInsets.all(12),
      child: Column(
        children: items
            .map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: item == items.last ? 0 : 10),
                child: _HourlyCongestionRow(
                  item: item,
                  onTap: () => _showSlotDetails(context, navigator, item),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  void _showSlotDetails(
    BuildContext context,
    NavigatorState navigator,
    _HourlyCongestion item,
  ) {
    final details = snapshot.detailsFor(item);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _HourlySlotDialog(
        item: item,
        details: details,
        onOpenMachine: (machine) {
          Navigator.of(dialogContext).pop();
          navigator.push(
            MaterialPageRoute(
              builder: (_) => MachineDetailPage(machineId: machine.machineId),
            ),
          );
        },
      ),
    );
  }
}

class _HourlyCongestionRow extends StatelessWidget {
  const _HourlyCongestionRow({required this.item, required this.onTap});

  final _HourlyCongestion item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              item.timeLabel,
              style: const TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 22,
              decoration: BoxDecoration(
                color: bgColor,
                border: Border.all(color: borderColor, width: 2),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              clipBehavior: Clip.antiAlias,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: item.ratio,
                  heightFactor: 1,
                  child: ColoredBox(color: item.color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 58,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: item.color,
              border: Border.all(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Text(
              item.statusLabel,
              style: const TextStyle(
                color: borderColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 42,
            child: Text(
              '${item.load}/${item.capacity}',
              textAlign: TextAlign.right,
              style: AppTextStyles.label,
            ),
          ),
          const Icon(Icons.chevron_right, color: textColor, size: 18),
        ],
      ),
    );
  }
}

class _HourlySlotDialog extends StatelessWidget {
  const _HourlySlotDialog({
    required this.item,
    required this.details,
    required this.onOpenMachine,
  });

  final _HourlyCongestion item;
  final _HourlySlotDetails details;
  final void Function(MachineModel machine) onOpenMachine;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: _StatusWobblyCard(
          seed: 'slot_dialog_${item.timeLabel}',
          rotation: -0.01,
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: item.color,
                      border: Border.all(color: borderColor, width: 3),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Text(
                      item.timeLabel,
                      style: const TextStyle(
                        color: borderColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${formatTimeOnly(item.startAt)} - ${formatTimeOnly(item.endAt)}',
                      style: const TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: borderColor),
                    tooltip: '닫기',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border.all(color: borderColor, width: 3),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Text(
                  '예약 ${details.reservedEntries.length}건 · 사용 ${details.useEntries.length}건',
                  style: const TextStyle(
                    color: borderColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (details.isEmpty)
                const _StatusEmptyPanel(text: '이 시간대에 표시할 기구가 없습니다.')
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _SlotDetailSection(
                        title: '예약된 기구',
                        entries: details.reservedEntries,
                        emptyText: '예약된 기구가 없습니다.',
                        onOpenMachine: onOpenMachine,
                      ),
                      const SizedBox(height: 12),
                      _SlotDetailSection(
                        title: '사용 중 / 사용 기록',
                        entries: details.useEntries,
                        emptyText: '사용 중인 기구가 없습니다.',
                        onOpenMachine: onOpenMachine,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotDetailSection extends StatelessWidget {
  const _SlotDetailSection({
    required this.title,
    required this.entries,
    required this.emptyText,
    required this.onOpenMachine,
  });

  final String title;
  final List<_SlotDetailEntry> entries;
  final String emptyText;
  final void Function(MachineModel machine) onOpenMachine;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            height: 1,
            shadows: [
              Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 0),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor, width: 2.5),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Text(
              emptyText,
              textAlign: TextAlign.center,
              style: AppTextStyles.empty,
            ),
          )
        else
          ...entries.asMap().entries.map(
            (entry) => Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == entries.length - 1 ? 0 : 8,
              ),
              child: _SlotDetailTile(
                entry: entry.value,
                onTap: entry.value.machine == null
                    ? null
                    : () => onOpenMachine(entry.value.machine!),
              ),
            ),
          ),
      ],
    );
  }
}

class _SlotDetailTile extends StatelessWidget {
  const _SlotDetailTile({required this.entry, required this.onTap});

  final _SlotDetailEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 2.5),
          borderRadius: BorderRadius.circular(AppRadii.sm),
          boxShadow: const [
            BoxShadow(color: borderColor, offset: Offset(2, 2), blurRadius: 0),
          ],
        ),
        child: Row(
          children: [
            Container(width: 6, height: 44, color: entry.color),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.itemTitle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: entry.color,
                          border: Border.all(color: borderColor, width: 2),
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                        child: Text(
                          entry.badge,
                          style: const TextStyle(
                            color: borderColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    entry.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: textColor, size: 20),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.snapshot});

  final _GymStatusSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: '사용 중',
            value: '${snapshot.activeUnits}/${snapshot.totalUnits}',
            color: redColor,
            icon: Icons.fitness_center,
            onTap: () => _showUsingMachines(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: '대기',
            value: '${snapshot.waitingTotal}',
            color: amberColor,
            icon: Icons.schedule,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: '점검',
            value: '${snapshot.repairCount}',
            color: const Color(0xFF777777),
            icon: Icons.build,
          ),
        ),
      ],
    );
  }

  void _showUsingMachines(BuildContext context) {
    final usingMachines = snapshot.usingMachines;
    final navigator = Navigator.of(context);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => _UsingMachinesDialog(
        entries: usingMachines,
        onOpenMachine: (machine) {
          Navigator.of(dialogContext).pop();
          navigator.push(
            MaterialPageRoute(
              builder: (_) => MachineDetailPage(machineId: machine.machineId),
            ),
          );
        },
      ),
    );
  }
}

class _UsingMachinesDialog extends StatelessWidget {
  const _UsingMachinesDialog({
    required this.entries,
    required this.onOpenMachine,
  });

  final List<_UsingMachine> entries;
  final void Function(MachineModel machine) onOpenMachine;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      child: Transform.rotate(
        angle: -0.012,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border.all(color: borderColor, width: 4),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              boxShadow: const [
                BoxShadow(
                  color: blueColor,
                  offset: Offset(5, 5),
                  blurRadius: 0,
                ),
                BoxShadow(
                  color: redColor,
                  offset: Offset(-2, -2),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: redColor,
                        border: Border.all(color: borderColor, width: 3),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: const Icon(
                        Icons.fitness_center,
                        color: borderColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '지금 사용 중',
                        style: TextStyle(
                          color: bgColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: borderColor),
                      tooltip: '닫기',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border.all(color: borderColor, width: 3),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Text(
                    entries.isEmpty
                        ? '러닝머신 제외 기준으로 사용 중인 기구가 없습니다.'
                        : '러닝머신 제외 · ${entries.length}개 기구 사용 중',
                    style: const TextStyle(
                      color: borderColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: AppEmptyPanel(text: '현재 사용 중인 기구가 없습니다.'),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 9),
                      itemBuilder: (context, index) => _UsingMachineDialogTile(
                        entry: entries[index],
                        onTap: () => onOpenMachine(entries[index].machine),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UsingMachineDialogTile extends StatelessWidget {
  const _UsingMachineDialogTile({required this.entry, required this.onTap});

  final _UsingMachine entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final userText = entry.users
        .map((reservation) => reservation.userName)
        .join(', ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 3),
          borderRadius: BorderRadius.circular(AppRadii.md),
          boxShadow: const [
            BoxShadow(color: borderColor, offset: Offset(2, 2), blurRadius: 0),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: redColor,
                border: Border.all(color: borderColor, width: 2.5),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                '${entry.activeCount}',
                style: const TextStyle(
                  color: borderColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.machine.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.itemTitle,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    userText.isEmpty ? '사용 중' : userText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: borderColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${entry.activeCount}/${entry.capacity}',
              style: const TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Icon(Icons.chevron_right, color: textColor),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        height: 92,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Color.lerp(color, bgColor, 0.25),
          border: Border.all(color: borderColor, width: 3),
          borderRadius: BorderRadius.circular(AppRadii.md),
          boxShadow: AppShadows.sticker,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: textColor, size: 22),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 0.95,
              ),
            ),
            Text(label, style: AppTextStyles.label),
          ],
        ),
      ),
    );
  }
}

class _CardioCapacityRow extends StatelessWidget {
  const _CardioCapacityRow({required this.snapshot});

  final _GymStatusSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final machines = snapshot.cardioMachines;
    if (machines.isEmpty) {
      return const _StatusEmptyPanel(text: '유산소 기구 정보를 찾을 수 없습니다.');
    }

    return Row(
      children: machines
          .map(
            (machine) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _MachineStatusTile(
                  title: machine.name,
                  subtitle: machine.status == MachineStatus.repair
                      ? '점검 중'
                      : '남은 자리 ${snapshot.remainingUnits(machine)}개',
                  trailing:
                      '${snapshot.remainingUnits(machine)}/${snapshot.provider.getMachineCapacity(machine.machineId)}',
                  color: machine.status == MachineStatus.repair
                      ? const Color(0xFF777777)
                      : greenColor,
                  compact: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          MachineDetailPage(machineId: machine.machineId),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MachineStatusTile extends StatelessWidget {
  const _MachineStatusTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 0 : 9),
      child: GestureDetector(
        onTap: onTap,
        child: _StatusWobblyCard(
          seed: 'machine_status_$title',
          fillColor: Color.lerp(color, bgColor, 0.28)!,
          padding: EdgeInsets.all(compact ? 10 : 12),
          margin: EdgeInsets.zero,
          shadows: compact ? chipShadows('machine_status_$title') : null,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.itemTitle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                trailing,
                style: const TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
