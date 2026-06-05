import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/reservation_model.dart';
import '../models/usage_log_model.dart';
import '../providers/gym_provider.dart';
import '../utils/status_utils.dart';
import '../utils/time_utils.dart';
import '../widgets/app_design.dart';
import '../widgets/reservation_card.dart';

class MyReservationPage extends StatefulWidget {
  const MyReservationPage({super.key});

  @override
  State<MyReservationPage> createState() => _MyReservationPageState();
}

class _MyReservationPageState extends State<MyReservationPage> {
  Future<void> _confirmCancel(
    BuildContext context,
    GymProvider provider,
    String reservationId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('예약 취소'),
        content: const Text('예약을 취소하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('아니오'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: redColor),
            child: const Text('취소'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final message = await provider.cancelReservation(reservationId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GymProvider>(
      builder: (context, provider, _) {
        final reservations = provider.getMyReservations();
        final logs = provider.getMyUsageLogs();
        final isLoading = provider.isActionLoading || provider.isLoading;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(
              title: const Text('내찜'),
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
              bottom: const TabBar(
                tabs: [
                  Tab(text: '예약 현황'),
                  Tab(text: '사용 기록'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _ReservationTab(
                  reservations: reservations,
                  isLoading: isLoading,
                  onRefresh: provider.syncFromDatabase,
                  onCancel: (id) => _confirmCancel(context, provider, id),
                  provider: provider,
                ),
                _HistoryTab(logs: logs, onRefresh: provider.syncFromDatabase),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReservationTab extends StatelessWidget {
  const _ReservationTab({
    required this.reservations,
    required this.isLoading,
    required this.onRefresh,
    required this.onCancel,
    required this.provider,
  });

  final List<ReservationModel> reservations;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final void Function(String id) onCancel;
  final GymProvider provider;

  @override
  Widget build(BuildContext context) {
    if (reservations.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: AppEmptyPanel(text: '예약한 기구가 없습니다.'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reservations.length,
        itemBuilder: (context, index) {
          final reservation = reservations[index];
          return ReservationCard(
            reservation: reservation,
            estimatedWaitMinutes: provider.getEstimatedWaitMinutes(
              reservation.machineId,
              reservation.userId,
            ),
            onCancel: isLoading
                ? null
                : () => onCancel(reservation.reservationId),
          );
        },
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.logs, required this.onRefresh});

  final List<UsageLogModel> logs;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: AppEmptyPanel(text: '사용 기록이 없습니다.'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          return AppRecordCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        log.machineName,
                        style: AppTextStyles.itemTitle,
                      ),
                    ),
                    Text(
                      '${log.usedMinutes}분',
                      style: const TextStyle(
                        color: blueColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AppInfoRow(
                  label: '사용 시간',
                  value: formatTimeRange(log.startedAt, log.endedAt),
                ),
                AppInfoRow(label: '날짜', value: formatDateTime(log.endedAt)),
              ],
            ),
          );
        },
      ),
    );
  }
}
