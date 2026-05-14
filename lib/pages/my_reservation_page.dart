import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/gym_provider.dart';
import '../utils/status_utils.dart';
import '../widgets/reservation_card.dart';

class MyReservationPage extends StatelessWidget {
  const MyReservationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GymProvider>(
      builder: (context, provider, _) {
        final reservations = provider.getMyReservations();

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(title: const Text('내 예약')),
          body: reservations.isEmpty
              ? const Center(
                  child: Text(
                    '예약한 기구가 없습니다.',
                    style: TextStyle(color: mutedTextColor),
                  ),
                )
              : ListView.builder(
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
                      onCancel: () async {
                        final message = await provider.cancelReservation(
                          reservation.reservationId,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(message)));
                      },
                    );
                  },
                ),
        );
      },
    );
  }
}
