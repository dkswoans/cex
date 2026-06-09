import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/machine_model.dart';
import '../providers/gym_provider.dart';
import '../utils/status_utils.dart';
import '../utils/time_utils.dart';
import '../widgets/app_design.dart';
import '../widgets/gym_map.dart';
import 'machine_detail_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GymProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.machines.isEmpty) {
          return const Scaffold(
            backgroundColor: bgColor,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (provider.errorMessage != null && provider.machines.isEmpty) {
          return Scaffold(
            backgroundColor: bgColor,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  provider.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: redColor),
                ),
              ),
            ),
          );
        }

        final reservationAlert = provider.getMyReservationAlert();
        final currentUser = provider.currentUser;
        final isAdmin = currentUser?.role == 'admin';

        return Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            child: Container(
              decoration: const BoxDecoration(color: bgColor),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      title: provider.homeTitle,
                      onRefresh: () async {
                        await provider.syncFromDatabase();
                        if (!context.mounted) return;
                        if (provider.errorMessage != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(provider.errorMessage!)),
                          );
                        }
                      },
                      onEditTitle: isAdmin
                          ? () => _showEditTitleDialog(context, provider)
                          : null,
                      isLoading: provider.isLoading,
                      isActionLoading: provider.isActionLoading,
                    ),
                    const SizedBox(height: 7),
                    _StatusSummary(
                      available: _count(provider, MachineStatus.available),
                      using: _count(provider, MachineStatus.using),
                      reserved: _count(provider, MachineStatus.reserved),
                      repair: _count(provider, MachineStatus.repair),
                      onStatusTap: (status) =>
                          _showMachinesByStatus(context, provider, status),
                    ),
                    if (reservationAlert != null) ...[
                      const SizedBox(height: 9),
                      _ReservationAlertPanel(
                        alert: reservationAlert,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MachineDetailPage(
                                machineId:
                                    reservationAlert.reservation.machineId,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 9),
                    Expanded(
                      child: GymMap(
                        machines: provider.machines,
                        onMachineTap: (machine) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MachineDetailPage(
                                machineId: machine.machineId,
                              ),
                            ),
                          );
                        },
                        getWaitingCount: provider.getWaitingCount,
                        getMarkerSummary: provider.getMachineMapSummary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  int _count(GymProvider provider, MachineStatus status) {
    return provider.machines
        .where((machine) => machine.status == status)
        .length;
  }

  void _showMachinesByStatus(
    BuildContext context,
    GymProvider provider,
    MachineStatus status,
  ) {
    final machines =
        provider.machines.where((machine) => machine.status == status).toList()
          ..sort((a, b) {
            final zoneCompare = a.zoneName.compareTo(b.zoneName);
            if (zoneCompare != 0) return zoneCompare;
            return a.name.compareTo(b.name);
          });
    final navigator = Navigator.of(context);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => _StatusMachinesDialog(
        status: status,
        machines: machines,
        provider: provider,
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

  Future<void> _showEditTitleDialog(
    BuildContext context,
    GymProvider provider,
  ) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _HomeTitleEditDialog(initialTitle: provider.homeTitle),
    );
    if (title == null) return;

    final message = await provider.updateHomeTitle(title);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReservationAlertPanel extends StatelessWidget {
  const _ReservationAlertPanel({required this.alert, required this.onTap});

  final ReservationAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isReady = alert.type == ReservationAlertType.ready;
    final title = isReady ? '예약 입장 가능' : '${alert.minutesUntilStart}분 후 예약';
    final icon = isReady ? Icons.notifications_active : Icons.schedule;
    final accentColor = isReady ? greenColor : amberColor;
    final subtitle =
        '${alert.reservation.machineName}  ${formatTimeRange(alert.reservation.reservedStartAt, alert.reservation.reservedEndAt)}';

    return Transform.rotate(
      angle: -0.01,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Color.lerp(accentColor, bgColor, 0.2),
            border: Border.all(color: borderColor, width: 3),
            borderRadius: BorderRadius.circular(AppRadii.md),
            boxShadow: const [
              BoxShadow(color: redColor, offset: Offset(4, 4), blurRadius: 0),
              BoxShadow(
                color: blueColor,
                offset: Offset(-2, -2),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border.all(color: borderColor, width: 3),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Icon(icon, color: textColor, size: 25),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: redColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: textColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onRefresh,
    required this.isLoading,
    required this.isActionLoading,
    this.onEditTitle,
  });

  final String title;
  final Future<void> Function() onRefresh;
  final bool isLoading;
  final bool isActionLoading;
  final VoidCallback? onEditTitle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.012,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border.all(color: borderColor, width: 4),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: AppShadows.loud,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Transform.rotate(
              angle: 0.32,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: blueColor,
                  border: Border.all(color: borderColor, width: 3),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.fitness_center,
                  color: textColor,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: bgColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  shadows: const [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(2, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
            if (onEditTitle != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: '홈 제목 수정',
                onPressed: isActionLoading ? null : onEditTitle,
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '새로고침',
              onPressed: isLoading ? null : onRefresh,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTitleEditDialog extends StatefulWidget {
  const _HomeTitleEditDialog({required this.initialTitle});

  final String initialTitle;

  @override
  State<_HomeTitleEditDialog> createState() => _HomeTitleEditDialogState();
}

class _HomeTitleEditDialogState extends State<_HomeTitleEditDialog> {
  late final TextEditingController _titleCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('홈 제목 수정'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            maxLength: 40,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: '홈 제목'),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: redColor, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('저장')),
      ],
    );
  }

  void _submit() {
    final title = _titleCtrl.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (title.isEmpty) {
      setState(() => _error = '제목을 입력하세요.');
      return;
    }
    if (title.length > 40) {
      setState(() => _error = '제목은 40자까지 입력할 수 있습니다.');
      return;
    }
    Navigator.pop(context, title);
  }
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({
    required this.available,
    required this.using,
    required this.reserved,
    required this.repair,
    required this.onStatusTap,
  });

  final int available;
  final int using;
  final int reserved;
  final int repair;
  final void Function(MachineStatus status) onStatusTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryItem(
            label: '쌉가능',
            value: available,
            color: greenColor,
            icon: Icons.thumb_up_alt,
            angle: -0.08,
            onTap: () => onStatusTap(MachineStatus.available),
          ),
        ),
        Expanded(
          child: _SummaryItem(
            label: '누가씀',
            value: using,
            color: redColor,
            icon: Icons.warning_amber,
            angle: 0.09,
            onTap: () => onStatusTap(MachineStatus.using),
          ),
        ),
        Expanded(
          child: _SummaryItem(
            label: '찜당함',
            value: reserved,
            color: amberColor,
            icon: Icons.local_fire_department,
            angle: -0.04,
            onTap: () => onStatusTap(MachineStatus.reserved),
          ),
        ),
        Expanded(
          child: _SummaryItem(
            label: '고장남',
            value: repair,
            color: const Color(0xFF6D6D6D),
            icon: Icons.dangerous,
            angle: 0.07,
            onTap: () => onStatusTap(MachineStatus.repair),
          ),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.angle,
    required this.onTap,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final double angle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          height: 82,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Color.lerp(color, bgColor, 0.22),
            border: Border.all(color: borderColor, width: 3),
            borderRadius: BorderRadius.circular(AppRadii.md),
            boxShadow: AppShadows.sticker,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: textColor),
              Text(
                '$value',
                style: const TextStyle(
                  color: textColor,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  height: 0.9,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: const TextStyle(
                  color: Color(0xFF003CFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusMachinesDialog extends StatelessWidget {
  const _StatusMachinesDialog({
    required this.status,
    required this.machines,
    required this.provider,
    required this.onOpenMachine,
  });

  final MachineStatus status;
  final List<MachineModel> machines;
  final GymProvider provider;
  final void Function(MachineModel machine) onOpenMachine;

  @override
  Widget build(BuildContext context) {
    final color = machineStatusColor(status);
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
                        color: color,
                        border: Border.all(color: borderColor, width: 3),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Icon(_statusIcon(status), color: borderColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        machineStatusText(status),
                        style: const TextStyle(
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
                    machines.isEmpty
                        ? '${machineStatusText(status)} 기구가 없습니다.'
                        : '${machineStatusText(status)} · ${machines.length}개',
                    style: const TextStyle(
                      color: borderColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (machines.isEmpty)
                  AppEmptyPanel(text: '${machineStatusText(status)} 기구가 없습니다.')
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: machines.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 9),
                      itemBuilder: (context, index) {
                        final machine = machines[index];
                        return _StatusMachineDialogTile(
                          machine: machine,
                          status: status,
                          provider: provider,
                          color: color,
                          onTap: () => onOpenMachine(machine),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _statusIcon(MachineStatus status) {
    return switch (status) {
      MachineStatus.available => Icons.thumb_up_alt,
      MachineStatus.using => Icons.warning_amber,
      MachineStatus.reserved => Icons.local_fire_department,
      MachineStatus.repair => Icons.dangerous,
    };
  }
}

class _StatusMachineDialogTile extends StatelessWidget {
  const _StatusMachineDialogTile({
    required this.machine,
    required this.status,
    required this.provider,
    required this.color,
    required this.onTap,
  });

  final MachineModel machine;
  final MachineStatus status;
  final GymProvider provider;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final capacity = provider.getMachineCapacity(machine.machineId);
    final activeCount = provider.getActiveCount(machine.machineId);
    final waitingCount = provider.getWaitingCount(machine.machineId);
    final subtitle = switch (status) {
      MachineStatus.available =>
        capacity > 1
            ? '남은 자리 ${provider.getRemainingUnitCount(machine.machineId)}개'
            : machine.zoneName,
      MachineStatus.using =>
        capacity > 1
            ? '사용 $activeCount/$capacity'
            : machine.currentUserName ?? '사용 중',
      MachineStatus.reserved =>
        waitingCount > 0 ? '대기 $waitingCount명' : '예약 대기 중',
      MachineStatus.repair => machine.zoneName,
    };

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
              width: 12,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: borderColor, width: 2),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    machine.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.itemTitle,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
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
            const Icon(Icons.chevron_right, color: textColor),
          ],
        ),
      ),
    );
  }
}
