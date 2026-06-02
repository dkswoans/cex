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
            .where((m) => m.status == MachineStatus.available)
            .length;
        final usingCount = provider.machines
            .where((m) => m.status == MachineStatus.using)
            .length;
        final repairCount = provider.machines
            .where((m) => m.status == MachineStatus.repair)
            .length;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: const Text('관리'),
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
              padding: const EdgeInsets.all(16),
              children: [
                const Text('기구 상태와 설정을 관리합니다.', style: AppTextStyles.label),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _MetricCard(label: '전체', value: '$totalCount')),
                    const SizedBox(width: 8),
                    Expanded(child: _MetricCard(label: '가능', value: '$availableCount')),
                    const SizedBox(width: 8),
                    Expanded(child: _MetricCard(label: '사용 중', value: '$usingCount')),
                    const SizedBox(width: 8),
                    Expanded(child: _MetricCard(label: '점검', value: '$repairCount')),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: provider.isActionLoading || provider.isLoading
                      ? null
                      : () => _confirmReset(context, provider),
                  icon: const Icon(Icons.restore),
                  label: const Text('데모 데이터 초기화'),
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
                              child: Text(machine.name, style: AppTextStyles.itemTitle),
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
                          value: '${provider.getWaitingCount(machine.machineId)}명',
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
                              onPressed: provider.isActionLoading || provider.isLoading
                                  ? null
                                  : () => _showEditDialog(context, provider, machine),
                              child: const Text('수정'),
                            ),
                            OutlinedButton(
                              onPressed: provider.isActionLoading || provider.isLoading
                                  ? null
                                  : () => _confirmToggleRepair(context, provider, machine),
                              style: machine.status == MachineStatus.repair
                                  ? OutlinedButton.styleFrom(foregroundColor: greenColor)
                                  : OutlinedButton.styleFrom(foregroundColor: redColor),
                              child: Text(
                                machine.status == MachineStatus.repair
                                    ? '점검 해제'
                                    : '점검 전환',
                              ),
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
          ),
        );
      },
    );
  }

  Future<void> _confirmToggleRepair(
    BuildContext context,
    GymProvider provider,
    MachineModel machine,
  ) async {
    final goingToRepair = machine.status != MachineStatus.repair;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(goingToRepair ? '점검 전환' : '점검 해제'),
        content: Text(
          goingToRepair
              ? '${machine.name}을(를) 점검 상태로 변경합니다.\n현재 예약이 모두 취소됩니다.'
              : '${machine.name}의 점검을 해제합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final message = await provider.toggleRepairStatus(machine.machineId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showEditDialog(
    BuildContext context,
    GymProvider provider,
    MachineModel machine,
  ) async {
    await showDialog(
      context: context,
      builder: (_) => _MachineEditDialog(machine: machine, provider: provider),
    );
  }

  Future<void> _confirmReset(BuildContext context, GymProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('데모 초기화'),
        content: const Text('모든 예약과 사용 기록이 삭제되고\n기구가 기본 상태로 초기화됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: redColor),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    await provider.resetMachinesForDemo();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('초기화가 완료되었습니다.')));
  }
}

class _MachineEditDialog extends StatefulWidget {
  const _MachineEditDialog({required this.machine, required this.provider});

  final MachineModel machine;
  final GymProvider provider;

  @override
  State<_MachineEditDialog> createState() => _MachineEditDialogState();
}

class _MachineEditDialogState extends State<_MachineEditDialog> {
  late final TextEditingController _minutesCtrl;
  late final TextEditingController _mapXCtrl;
  late final TextEditingController _mapYCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _minutesCtrl = TextEditingController(
      text: widget.machine.maxUseMinutes.toString(),
    );
    _mapXCtrl = TextEditingController(
      text: widget.machine.mapX.toStringAsFixed(3),
    );
    _mapYCtrl = TextEditingController(
      text: widget.machine.mapY.toStringAsFixed(3),
    );
  }

  @override
  void dispose() {
    _minutesCtrl.dispose();
    _mapXCtrl.dispose();
    _mapYCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.machine.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _minutesCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '최대 사용 시간 (분)',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _mapXCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '지도 X (0~1)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _mapYCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '지도 Y (0~1)'),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: redColor, fontSize: 12)),
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

  Future<void> _submit() async {
    final minutes = int.tryParse(_minutesCtrl.text.trim());
    final mapX = double.tryParse(_mapXCtrl.text.trim());
    final mapY = double.tryParse(_mapYCtrl.text.trim());

    if (minutes == null || minutes < 1 || minutes > 120) {
      setState(() => _error = '사용 시간은 1~120 사이 숫자로 입력하세요.');
      return;
    }
    if (mapX == null || mapX < 0 || mapX > 1) {
      setState(() => _error = 'X 좌표는 0~1 사이 숫자로 입력하세요.');
      return;
    }
    if (mapY == null || mapY < 0 || mapY > 1) {
      setState(() => _error = 'Y 좌표는 0~1 사이 숫자로 입력하세요.');
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);

    final message = await widget.provider.updateMachineSettings(
      widget.machine.machineId,
      maxUseMinutes: minutes,
      mapX: mapX,
      mapY: mapY,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
        border: Border.all(color: borderColor, width: 3),
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: AppShadows.sticker,
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
