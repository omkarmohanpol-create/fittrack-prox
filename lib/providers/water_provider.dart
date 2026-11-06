import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/local_store.dart';
import '../services/supabase_service.dart';
import '../services/sync_errors.dart';
import '../utils/formatters.dart';

class WaterProvider extends ChangeNotifier {
  List<WaterLog> _logs = [];
  Set<String> _pendingIds = {};

  List<WaterLog> get logs => List.unmodifiable(_logs);
  bool isPending(String id) => _pendingIds.contains(id);
  int get pendingCount => _pendingIds.length;

  static List<WaterLog> merge(List<WaterLog> loaded, List<WaterLog> pending) {
    final ids = pending.map((l) => l.id).toSet();
    return [...pending, ...loaded.where((l) => !ids.contains(l.id))];
  }

  /// Signed-in users read from Supabase (falling back to the offline cache);
  /// guests read what is saved on the device.
  Future<void> load() async {
    final uid = SupabaseService.userId;
    if (uid == null) {
      _logs = await LocalStore.loadWater();
      _pendingIds = {};
      notifyListeners();
      return;
    }
    final pending = await _flush(uid, await LocalStore.loadPendingWater(uid));
    try {
      final remote = await SupabaseService.fetchWaterLogs(
        since: DateTime.now().subtract(const Duration(days: 30)),
      );
      _logs = merge(remote, pending);
      await LocalStore.cacheWater(uid, remote);
    } catch (_) {
      _logs = merge(await LocalStore.loadCachedWater(uid), pending);
    }
    _pendingIds = pending.map((l) => l.id).toSet();
    notifyListeners();
  }

  Future<List<WaterLog>> _flush(String uid, List<WaterLog> pending) async {
    if (pending.isEmpty) return pending;
    final left = <WaterLog>[];
    for (final l in pending) {
      try {
        await SupabaseService.insertWaterLog(l);
      } catch (_) {
        left.add(l);
      }
    }
    if (left.length != pending.length) {
      await LocalStore.savePendingWater(uid, left);
    }
    return left;
  }

  Future<void> syncPending() async {
    final uid = SupabaseService.userId;
    if (uid == null || _pendingIds.isEmpty) return;
    final left = await _flush(uid, await LocalStore.loadPendingWater(uid));
    final ids = left.map((l) => l.id).toSet();
    if (ids.length != _pendingIds.length) {
      _pendingIds = ids;
      notifyListeners();
    }
  }

  Future<void> _persist(String? uid) async {
    if (uid == null) {
      // Keep two months on the device; the app only charts the last 30 days.
      final cutoff = Formatters.dateOnly(DateTime.now())
          .subtract(const Duration(days: 60));
      await LocalStore.saveWater(
        _logs.where((l) => !l.date.isBefore(cutoff)).toList(),
      );
    } else {
      await LocalStore.cacheWater(
        uid,
        _logs.where((l) => !_pendingIds.contains(l.id)).toList(),
      );
    }
  }

  List<WaterLog> logsFor(DateTime day) {
    final d = Formatters.dateOnly(day);
    return _logs
        .where((l) => Formatters.dateOnly(l.date) == d)
        .toList(growable: false);
  }

  int totalFor(DateTime day) => logsFor(day).fold(0, (s, l) => s + l.amountMl);

  int get todayMl => totalFor(DateTime.now());

  /// Totals for the last [days] days, oldest first.
  List<int> lastDays(int days) {
    final today = Formatters.dateOnly(DateTime.now());
    return List.generate(
      days,
      (i) => totalFor(today.subtract(Duration(days: days - 1 - i))),
    );
  }

  /// Returns null on success, or an error message. Offline, the entry is kept
  /// on the device and uploaded on the next sync.
  Future<String?> add(int ml) async {
    if (ml <= 0) return null;
    final uid = SupabaseService.userId;
    final log = WaterLog(
      id: newUuid(),
      amountMl: ml,
      date: Formatters.dateOnly(DateTime.now()),
    );
    if (uid != null) {
      try {
        await SupabaseService.insertWaterLog(log);
      } catch (e) {
        if (isServerRejection(e)) {
          return 'Could not save the water entry. Please try again.';
        }
        _pendingIds.add(log.id);
        final list = await LocalStore.loadPendingWater(uid);
        await LocalStore.savePendingWater(uid, [log, ...list]);
      }
    }
    _logs = [log, ..._logs];
    notifyListeners();
    await _persist(uid);
    return null;
  }

  /// Removes the most recent entry for today (the "-" button).
  Future<String?> undoLast() async {
    final todays = logsFor(DateTime.now());
    if (todays.isEmpty) return null;
    return remove(todays.first.id);
  }

  /// Returns null on success, or an error message.
  Future<String?> remove(String id) async {
    final uid = SupabaseService.userId;
    if (uid != null) {
      if (_pendingIds.remove(id)) {
        final list = await LocalStore.loadPendingWater(uid);
        await LocalStore.savePendingWater(
          uid,
          list.where((l) => l.id != id).toList(),
        );
        try {
          await SupabaseService.deleteWaterLog(id);
        } catch (_) {}
      } else if (!isLocalId(id)) {
        try {
          await SupabaseService.deleteWaterLog(id);
        } catch (_) {
          return 'Could not delete the entry. Check your connection.';
        }
      }
    }
    _logs = _logs.where((l) => l.id != id).toList();
    notifyListeners();
    await _persist(uid);
    return null;
  }

  /// Clears what is on screen. Saved data on the device is kept.
  void clear() {
    _logs = [];
    _pendingIds = {};
    notifyListeners();
  }
}
