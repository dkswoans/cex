import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/reservation_model.dart';
import '../utils/time_utils.dart';

enum _ReservationNotificationKind { upcoming, ready, noShow }

class ReservationNotificationService {
  ReservationNotificationService._();

  static final ReservationNotificationService instance =
      ReservationNotificationService._();

  static const _payloadPrefix = 'apdo_reservation';
  static const _channelId = 'reservation_alerts';
  static const _channelName = '예약 알림';
  static const _channelDescription = '예약 시작 전, 입장 가능, 노쇼 임박 알림';
  static const _notificationIcon = 'ic_stat_reservation';
  static const _leadTime = Duration(minutes: 5);
  static const _noShowLeadTime = Duration(seconds: 30);

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionsRequested = false;
  bool _exactAlarmsAllowed = true;
  final Set<String> _shownImmediateReadyKeys = {};

  Future<void> initialize() async {
    if (_initialized || kIsWeb || !_isSupportedPlatform) return;

    try {
      tz.initializeTimeZones();
      await _setLocalLocation();

      const androidSettings = AndroidInitializationSettings(_notificationIcon);
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: '열기',
      );
      const windowsSettings = WindowsInitializationSettings(
        appName: '압도정진올라잇삼창돌격',
        appUserModelId: 'Apdo.GymReservation.App',
        guid: 'f0f5b6e1-4d2a-4e94-9a6b-1d8b14bb18a4',
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
        windows: windowsSettings,
      );

      await _notifications.initialize(settings: settings);
      _initialized = true;
    } catch (error) {
      debugPrint('[ReservationNotificationService] initialize error: $error');
    }
  }

  Future<void> syncForUserReservations({
    required String userId,
    required Iterable<ReservationModel> reservations,
    Set<String> claimedReservationIds = const <String>{},
    DateTime? now,
  }) async {
    if (kIsWeb || !_isSupportedPlatform) return;
    await initialize();
    if (!_initialized) return;

    final activeReservations =
        reservations.where(_isSchedulableReservation).toList()..sort((a, b) {
          final aStart = a.reservedStartAt ?? a.createdAt;
          final bStart = b.reservedStartAt ?? b.createdAt;
          return aStart.compareTo(bStart);
        });

    await _cancelPendingUserReservationNotifications(userId);
    if (activeReservations.isEmpty) return;

    await _requestPermissions();

    final currentTime = now ?? DateTime.now();
    final liveImmediateReadyKeys = activeReservations
        .map((reservation) => _immediateReadyKey(userId, reservation))
        .toSet();
    _shownImmediateReadyKeys.removeWhere(
      (key) =>
          key.startsWith('$userId:') && !liveImmediateReadyKeys.contains(key),
    );

    for (final reservation in activeReservations) {
      await _scheduleReservationNotifications(
        userId: userId,
        reservation: reservation,
        isClaimed: claimedReservationIds.contains(reservation.reservationId),
        now: currentTime,
      );
    }
  }

  Future<void> cancelUserReservations(String userId) async {
    if (kIsWeb || !_isSupportedPlatform) return;
    await initialize();
    if (!_initialized) return;
    await _cancelPendingUserReservationNotifications(userId);
  }

  Future<void> cancelAllReservationNotifications() async {
    if (kIsWeb || !_isSupportedPlatform) return;
    await initialize();
    if (!_initialized) return;

    try {
      final pending = await _notifications.pendingNotificationRequests();
      for (final request in pending) {
        if (_isReservationPayload(request.payload)) {
          await _notifications.cancel(id: request.id);
        }
      }
    } catch (error) {
      debugPrint(
        '[ReservationNotificationService] cancelAllReservationNotifications '
        'error: $error',
      );
    }
  }

  Future<void> _scheduleReservationNotifications({
    required String userId,
    required ReservationModel reservation,
    required bool isClaimed,
    required DateTime now,
  }) async {
    final startAt = reservation.reservedStartAt;
    final endAt = reservation.reservedEndAt;
    if (startAt == null || endAt == null || !now.isBefore(endAt)) return;

    final upcomingAt = startAt.subtract(_leadTime);
    if (now.isBefore(upcomingAt)) {
      await _scheduleNotification(
        userId: userId,
        reservation: reservation,
        kind: _ReservationNotificationKind.upcoming,
        scheduledAt: upcomingAt,
        title: '예약 5분 전',
        body:
            '${reservation.machineName} 예약이 '
            '${formatTimeOnly(startAt)}에 시작됩니다.',
      );
    }

    if (reservation.status == ReservationStatus.active &&
        !isClaimed &&
        !now.isBefore(startAt)) {
      await _showImmediateReadyNotification(
        userId: userId,
        reservation: reservation,
      );
    } else if (now.isBefore(startAt)) {
      await _scheduleNotification(
        userId: userId,
        reservation: reservation,
        kind: _ReservationNotificationKind.ready,
        scheduledAt: startAt,
        title: '예약 입장 가능',
        body: '${reservation.machineName} 사용 시간이 시작됐습니다.',
      );
    }

    final claimExpiresAt =
        reservation.claimExpiresAt ?? startAt.add(const Duration(minutes: 1));
    final noShowReminderAt = claimExpiresAt.subtract(_noShowLeadTime);
    final isNoShowReminderUseful =
        !isClaimed &&
        now.isBefore(noShowReminderAt) &&
        noShowReminderAt.isAfter(startAt) &&
        noShowReminderAt.isBefore(endAt);
    if (isNoShowReminderUseful) {
      await _scheduleNotification(
        userId: userId,
        reservation: reservation,
        kind: _ReservationNotificationKind.noShow,
        scheduledAt: noShowReminderAt,
        title: '입장 확인 임박',
        body: '${reservation.machineName} 사용 시작을 놓치지 마세요.',
      );
    }
  }

  Future<void> _scheduleNotification({
    required String userId,
    required ReservationModel reservation,
    required _ReservationNotificationKind kind,
    required DateTime scheduledAt,
    required String title,
    required String body,
  }) async {
    final id = _notificationId(reservation.reservationId, kind);
    final payload = _notificationPayload(
      userId: userId,
      reservation: reservation,
      kind: kind,
    );
    final scheduledDate = tz.TZDateTime.from(scheduledAt, tz.local);
    final details = _notificationDetails();

    try {
      await _notifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        payload: payload,
        androidScheduleMode: _exactAlarmsAllowed
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (error) {
      if (!_exactAlarmsAllowed) {
        debugPrint('[ReservationNotificationService] schedule error: $error');
        return;
      }

      _exactAlarmsAllowed = false;
      debugPrint(
        '[ReservationNotificationService] exact schedule failed, '
        'falling back to inexact: $error',
      );
      await _notifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> _showImmediateReadyNotification({
    required String userId,
    required ReservationModel reservation,
  }) async {
    final key = _immediateReadyKey(userId, reservation);
    if (_shownImmediateReadyKeys.contains(key)) return;

    final kind = _ReservationNotificationKind.ready;
    final id = _notificationId(reservation.reservationId, kind);
    final payload = _notificationPayload(
      userId: userId,
      reservation: reservation,
      kind: kind,
    );

    try {
      await _notifications.show(
        id: id,
        title: '예약 입장 가능',
        body: '${reservation.machineName} 사용 시간이 시작됐습니다.',
        notificationDetails: _notificationDetails(),
        payload: payload,
      );
      _shownImmediateReadyKeys.add(key);
    } catch (error) {
      debugPrint(
        '[ReservationNotificationService] immediate ready error: $error',
      );
    }
  }

  NotificationDetails _notificationDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        icon: _notificationIcon,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  String _notificationPayload({
    required String userId,
    required ReservationModel reservation,
    required _ReservationNotificationKind kind,
  }) {
    return '$_payloadPrefix:$userId:${reservation.reservationId}:${kind.name}';
  }

  String _immediateReadyKey(String userId, ReservationModel reservation) {
    return '$userId:${reservation.reservationId}:ready';
  }

  Future<void> _cancelPendingUserReservationNotifications(String userId) async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      final userPrefix = '$_payloadPrefix:$userId:';
      for (final request in pending) {
        if (request.payload?.startsWith(userPrefix) ?? false) {
          await _notifications.cancel(id: request.id);
        }
      }
    } catch (error) {
      debugPrint(
        '[ReservationNotificationService] cancelPending error: $error',
      );
    }
  }

  Future<void> _requestPermissions() async {
    if (_permissionsRequested) return;
    _permissionsRequested = true;

    try {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
      final exactPermission = await android?.requestExactAlarmsPermission();
      _exactAlarmsAllowed = exactPermission ?? true;

      final ios = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);

      final macOS = _notifications
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      await macOS?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (error) {
      debugPrint('[ReservationNotificationService] permission error: $error');
    }
  }

  Future<void> _setLocalLocation() async {
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    } catch (error) {
      debugPrint('[ReservationNotificationService] timezone fallback: $error');
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    }
  }

  bool _isSchedulableReservation(ReservationModel reservation) {
    return reservation.status == ReservationStatus.waiting ||
        reservation.status == ReservationStatus.active;
  }

  bool _isReservationPayload(String? payload) {
    return payload?.startsWith('$_payloadPrefix:') ?? false;
  }

  bool get _isSupportedPlatform {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  int _notificationId(String reservationId, _ReservationNotificationKind kind) {
    var hash = 0x811c9dc5;
    for (final codeUnit in '$reservationId:${kind.name}'.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
