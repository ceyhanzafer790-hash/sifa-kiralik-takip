import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'sync_worker.dart';
import 'file_sync_worker.dart';
import 'reminder_planner.dart';
import 'conflict_service.dart';

class AutoSyncCoordinator {
  AutoSyncCoordinator({
    SyncWorker? worker,
    FileSyncWorker? fileWorker,
    ReminderPlanner? reminderPlanner,
    ConflictService? conflictService,
    this.interval = const Duration(minutes: 1),
  })  : worker = worker ?? SyncWorker(),
        fileWorker = fileWorker ?? FileSyncWorker(),
        reminderPlanner = reminderPlanner ?? ReminderPlanner(),
        conflictService = conflictService ?? ConflictService();

  final SyncWorker worker;
  final FileSyncWorker fileWorker;
  final ReminderPlanner reminderPlanner;
  final ConflictService conflictService;
  final Duration interval;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _timer;
  bool _running = false;
  bool _started = false;

  final _status = StreamController<AutoSyncStatus>.broadcast();
  Stream<AutoSyncStatus> get statusStream => _status.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    await reminderPlanner.refresh();

    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) {
      final online = !results.contains(ConnectivityResult.none);
      if (online) syncNow();
    });

    _timer = Timer.periodic(interval, (_) => syncNow());
    await syncNow();
  }

  Future<void> syncNow() async {
    if (_running) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      await reminderPlanner.refresh();
      _status.add(
        AutoSyncStatus.offline(
          reminders: await reminderPlanner.pendingCount(),
          conflicts: await conflictService.openCount(),
        ),
      );
      return;
    }

    _running = true;
    _status.add(const AutoSyncStatus.syncing());

    try {
      final result = await worker.runFullSync();
      final files = await fileWorker.flush();
      await reminderPlanner.refresh();

      _status.add(
        AutoSyncStatus.ready(
          pending: result.remaining + files.remaining,
          pushed: result.sent + files.sent,
          pulled: result.pulled,
          failed: result.failed + files.failed,
          conflicts: await conflictService.openCount(),
          reminders: await reminderPlanner.pendingCount(),
        ),
      );
    } catch (e) {
      _status.add(AutoSyncStatus.error(e.toString()));
    } finally {
      _running = false;
    }
  }

  Future<void> stop() async {
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  Future<void> dispose() async {
    await stop();
    await _status.close();
  }
}

class AutoSyncStatus {
  final bool online;
  final bool syncing;
  final int pending;
  final int pushed;
  final int pulled;
  final int failed;
  final int conflicts;
  final int reminders;
  final String? error;

  const AutoSyncStatus._({
    required this.online,
    required this.syncing,
    this.pending = 0,
    this.pushed = 0,
    this.pulled = 0,
    this.failed = 0,
    this.conflicts = 0,
    this.reminders = 0,
    this.error,
  });

  const AutoSyncStatus.offline({
    int conflicts = 0,
    int reminders = 0,
  }) : this._(
          online: false,
          syncing: false,
          conflicts: conflicts,
          reminders: reminders,
        );

  const AutoSyncStatus.syncing()
      : this._(online: true, syncing: true);

  const AutoSyncStatus.ready({
    required int pending,
    required int pushed,
    required int pulled,
    required int failed,
    int conflicts = 0,
    int reminders = 0,
  }) : this._(
          online: true,
          syncing: false,
          pending: pending,
          pushed: pushed,
          pulled: pulled,
          failed: failed,
          conflicts: conflicts,
          reminders: reminders,
        );

  AutoSyncStatus.error(String error)
      : this._(
          online: true,
          syncing: false,
          error: error,
        );
}
