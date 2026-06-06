import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/machine_model.dart';
import '../models/reservation_model.dart';
import '../providers/gym_provider.dart';
import '../utils/status_utils.dart';
import '../widgets/app_design.dart';
import 'machine_detail_page.dart';

class StatusPage extends StatelessWidget {
  const StatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GymProvider>(
      builder: (context, provider, _) {
        final snapshot = _GymStatusSnapshot(provider);
        final topWaiting = snapshot.topWaitingMachines.take(3).toList();
        final availableNow = snapshot.availableMachines.take(8).toList();

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
                const AppSectionTitle('러닝/사이클 자리'),
                _CardioCapacityRow(snapshot: snapshot),
                const SizedBox(height: 18),
                const AppSectionTitle('대기 많은 기구'),
                if (topWaiting.isEmpty)
                  const AppEmptyPanel(text: '대기 중인 기구가 없습니다.')
                else
                  ...topWaiting.map(
                    (entry) => _MachineStatusTile(
                      title: entry.machine.name,
                      subtitle: '대기 ${entry.waitingCount}명',
                      trailing: '${entry.activeCount}/${entry.capacity}',
                      color: amberColor,
                      onTap: () => _openDetail(context, entry.machine),
                    ),
                  ),
                const SizedBox(height: 18),
                const AppSectionTitle('지금 바로 가능'),
                if (availableNow.isEmpty)
                  const AppEmptyPanel(text: '지금 바로 사용 가능한 기구가 없습니다.')
                else
                  Wrap(
                    spacing: 9,
                    runSpacing: 10,
                    children: availableNow
                        .map(
                          (machine) => _AvailableMachineChip(
                            machine: machine,
                            remainingText: snapshot.remainingText(machine),
                            onTap: () => _openDetail(context, machine),
                          ),
                        )
                        .toList(),
                  ),
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
    : activeUnits = _activeUnits(provider),
      totalUnits = _totalUnits(provider),
      waitingTotal = _waitingTotal(provider),
      repairCount = provider.machines
          .where((machine) => machine.status == MachineStatus.repair)
          .length;

  final GymProvider provider;
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

  List<MachineModel> get availableMachines {
    final result =
        provider.machines
            .where(
              (machine) =>
                  machine.status != MachineStatus.repair &&
                  provider.hasAvailableUnitNow(machine.machineId),
            )
            .toList()
          ..sort((a, b) {
            final zoneCompare = a.zoneName.compareTo(b.zoneName);
            if (zoneCompare != 0) return zoneCompare;
            return a.name.compareTo(b.name);
          });
    return result;
  }

  List<_WaitingMachine> get topWaitingMachines {
    final result =
        provider.machines
            .map((machine) {
              final waitingCount = provider.getWaitingCount(machine.machineId);
              return _WaitingMachine(
                machine: machine,
                waitingCount: waitingCount,
                activeCount: provider.getActiveCount(machine.machineId),
                capacity: provider.getMachineCapacity(machine.machineId),
              );
            })
            .where((entry) => entry.waitingCount > 0)
            .toList()
          ..sort((a, b) {
            final waitingCompare = b.waitingCount.compareTo(a.waitingCount);
            if (waitingCompare != 0) return waitingCompare;
            return b.activeCount.compareTo(a.activeCount);
          });
    return result;
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

  String remainingText(MachineModel machine) {
    final capacity = provider.getMachineCapacity(machine.machineId);
    if (capacity <= 1) return '가능';
    return '${remainingUnits(machine)}/$capacity';
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
}

class _WaitingMachine {
  const _WaitingMachine({
    required this.machine,
    required this.waitingCount,
    required this.activeCount,
    required this.capacity,
  });

  final MachineModel machine;
  final int waitingCount;
  final int activeCount;
  final int capacity;
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

class _CongestionPanel extends StatelessWidget {
  const _CongestionPanel({required this.snapshot});

  final _GymStatusSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.01,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border.all(color: borderColor, width: 4),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: const [
            BoxShadow(color: blueColor, offset: Offset(5, 5), blurRadius: 0),
            BoxShadow(color: redColor, offset: Offset(-2, -2), blurRadius: 0),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 82,
              height: 82,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: snapshot.congestionColor,
                shape: BoxShape.circle,
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
      return const AppEmptyPanel(text: '유산소 기구 정보를 찾을 수 없습니다.');
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          padding: EdgeInsets.all(compact ? 10 : 12),
          decoration: BoxDecoration(
            color: Color.lerp(color, bgColor, 0.28),
            border: Border.all(color: borderColor, width: 3),
            borderRadius: BorderRadius.circular(AppRadii.md),
            boxShadow: compact ? null : AppShadows.sticker,
          ),
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

class _AvailableMachineChip extends StatelessWidget {
  const _AvailableMachineChip({
    required this.machine,
    required this.remainingText,
    required this.onTap,
  });

  final MachineModel machine;
  final String remainingText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: greenColor,
          border: Border.all(color: borderColor, width: 2.5),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: const [
            BoxShadow(color: borderColor, offset: Offset(2, 2), blurRadius: 0),
          ],
        ),
        child: Text(
          '${machine.shortName} $remainingText',
          style: const TextStyle(
            color: borderColor,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
