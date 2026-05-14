import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/machine_model.dart';
import '../providers/gym_provider.dart';
import '../utils/status_utils.dart';
import '../widgets/app_design.dart';
import '../widgets/status_badge.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GymProvider>(
      builder: (context, provider, _) {
        final totalCount = provider.machines.length;
        final availableCount = provider.machines
            .where((machine) => machine.status == MachineStatus.available)
            .length;
        final usingCount = provider.machines
            .where((machine) => machine.status == MachineStatus.using)
            .length;
        final repairCount = provider.machines
            .where((machine) => machine.status == MachineStatus.repair)
            .length;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(title: const Text('관리')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _comingSoon(context),
            backgroundColor: blueColor,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('기구 추가'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('기구 상태와 지도 좌표를 확인합니다.', style: AppTextStyles.label),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(label: '전체', value: '$totalCount'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricCard(label: '가능', value: '$availableCount'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricCard(label: '사용 중', value: '$usingCount'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricCard(label: '점검', value: '$repairCount'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const AppSectionTitle('기구 목록'),
              ...provider.machines.map(
                (machine) => AppRecordCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              machine.name,
                              style: AppTextStyles.itemTitle,
                            ),
                          ),
                          StatusBadge(status: machine.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppInfoRow(
                        label: '최대 사용 시간',
                        value: '${machine.maxUseMinutes}분',
                      ),
                      AppInfoRow(
                        label: '현재 사용자',
                        value: machine.currentUserName ?? '-',
                      ),
                      AppInfoRow(
                        label: '대기 인원',
                        value:
                            '${provider.getWaitingCount(machine.machineId)}명',
                      ),
                      AppInfoRow(
                        label: '지도 좌표',
                        value:
                            '${machine.mapX.toStringAsFixed(2)}, ${machine.mapY.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => _comingSoon(context),
                            child: const Text('수정'),
                          ),
                          OutlinedButton(
                            onPressed: () => _comingSoon(context),
                            child: const Text('점검 전환'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 72),
            ],
          ),
        );
      },
    );
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('추후 구현 예정입니다.')));
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: blueColor,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const Spacer(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.label.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
