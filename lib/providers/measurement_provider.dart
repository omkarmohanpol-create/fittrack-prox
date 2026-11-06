import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/local_store.dart';
import '../services/supabase_service.dart';
import '../services/sync_errors.dart';

class MeasurementProvider extends ChangeNotifier {
  List<BodyMeasurement> _items = []; // newest first

  List<BodyMeasurement> get items => List.unmodifiable(_items);

  static List<BodyMeasurement> sortByDate(Iterable<BodyMeasurement> items) {
    final indexed = items.toList().asMap().entries.toList();
    indexed.sort((a, b) {
      final byDate = b.value.date.compareTo(a.value.date);
      return byDate != 0 ? byDate : a.key.compareTo(b.key);
    });
    return [for (final e in indexed) e.value];
  }

  Future<void> load() async {
    final uid = SupabaseService.userId;
    if (uid == null) {
      _items = sortByDate(await LocalStore.loadMeasurements());
      notifyListeners();
      return;
    }
    try {
      _items = await SupabaseService.fetchMeasurements();
      await LocalStore.cacheMeasurements(uid, _items);
    } catch (_) {
      _items = sortByDate(await LocalStore.loadCachedMeasurements(uid));
    }
    notifyListeners();
  }

  /// Returns null on success, or an error message.
  Future<String?> add(BodyMeasurement m) async {
    if (m.isEmpty) return 'Enter at least one measurement';
    final uid = SupabaseService.userId;
    if (uid != null) {
      try {
        await SupabaseService.insertMeasurement(m);
      } catch (e) {
        return isServerRejection(e)
            ? 'Could not save. Check the values and try again.'
            : 'Saving measurements needs a connection.';
      }
    }
    _items = sortByDate([m, ..._items.where((x) => x.id != m.id)]);
    notifyListeners();
    await _persist(uid);
    return null;
  }

  Future<String?> remove(String id) async {
    final uid = SupabaseService.userId;
    if (uid != null) {
      try {
        await SupabaseService.deleteMeasurement(id);
      } catch (_) {
        return 'Could not delete the entry. Check your connection.';
      }
    }
    _items = _items.where((m) => m.id != id).toList();
    notifyListeners();
    await _persist(uid);
    return null;
  }

  Future<void> _persist(String? uid) => uid == null
      ? LocalStore.saveMeasurements(_items)
      : LocalStore.cacheMeasurements(uid, _items);

  /// The most recent value of one field, and the one before it (for a change
  /// indicator). Entries without that field are skipped.
  (double?, double?) latestTwo(double? Function(BodyMeasurement) field) {
    double? latest;
    for (final m in _items) {
      final v = field(m);
      if (v == null) continue;
      if (latest == null) {
        latest = v;
      } else {
        return (latest, v);
      }
    }
    return (latest, null);
  }

  /// Oldest-first (date, value) points for one field, for charting.
  List<(DateTime, double)> series(double? Function(BodyMeasurement) field) => [
        for (final m in _items.reversed)
          if (field(m) != null) (m.date, field(m)!),
      ];

  void clear() {
    _items = [];
    notifyListeners();
  }
}
