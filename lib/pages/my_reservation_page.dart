import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/gym_provider.dart';
import '../utils/status_utils.dart';
import '../widgets/app_design.dart';
import '../widgets/reservation_card.dart';

class MyReservationPage extends StatefulWidget {
  const MyReservationPage({super.key});

  @override
  State<MyReservationPage> createState() => _MyReservationPageState();
}

class _MyReservationPageState extends State<MyReservationPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        context.read<GymProvider>().syncFromDatabase();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GymProvider>(
      builder: (context, provider, _) {
        final reservations = provider.getMyReservations();
        final isLoading = provider.isActionLoading || provider.isLoading;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: const Text('내 예약'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: '새로고침',
                onPressed: provider.isLoading ? null : () => provider.syncFromDatabase(),
              ),
            ],
          ),
          body: reservations.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: AppEmptyPanel(text: '예약한 기구가 없습니다.'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: provider.syncFromDatabase,
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
                            : () => _confirmCancel(
                                context,
                                provider,
                                reservation.reservationId,
                              ),
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}
