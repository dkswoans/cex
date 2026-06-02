import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/machine_model.dart';
import '../providers/gym_provider.dart';
import '../utils/status_utils.dart';
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
                      onRefresh: () async {
                        await provider.syncFromDatabase();
                        if (!context.mounted) return;
                        if (provider.errorMessage != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(provider.errorMessage!)),
                          );
                        }
                      },
                      isLoading: provider.isLoading,
                    ),
                    const SizedBox(height: 7),
                    _StatusSummary(
                      available: _count(provider, MachineStatus.available),
                      using: _count(provider, MachineStatus.using),
                      reserved: _count(provider, MachineStatus.reserved),
                      repair: _count(provider, MachineStatus.repair),
                    ),
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
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh, required this.isLoading});

  final Future<void> Function() onRefresh;
  final bool isLoading;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'APDO GYM!!!',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
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
                  const Text(
                    '운동기구 예약 현황임 아무튼',
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      color: greenColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
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

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({
    required this.available,
    required this.using,
    required this.reserved,
    required this.repair,
  });

  final int available;
  final int using;
  final int reserved;
  final int repair;

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
          ),
        ),
        Expanded(
          child: _SummaryItem(
            label: '누가씀',
            value: using,
            color: redColor,
            icon: Icons.warning_amber,
            angle: 0.09,
          ),
        ),
        Expanded(
          child: _SummaryItem(
            label: '찜당함',
            value: reserved,
            color: amberColor,
            icon: Icons.local_fire_department,
            angle: -0.04,
          ),
        ),
        Expanded(
          child: _SummaryItem(
            label: '고장남',
            value: repair,
            color: const Color(0xFF6D6D6D),
            icon: Icons.dangerous,
            angle: 0.07,
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
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
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
                color: redColor,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
