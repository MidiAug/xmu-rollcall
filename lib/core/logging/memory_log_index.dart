import 'package:xmu_rollcall/core/logging/log_record.dart';

/// In-memory ring of redacted [LogRecord]s for the recent-logs UI.
class MemoryLogIndex {
  MemoryLogIndex({this.capacity = 400});

  final int capacity;
  final List<LogRecord> _items = [];

  int get length => _items.length;

  List<LogRecord> get recent => List.unmodifiable(_items);

  void clear() => _items.clear();

  void add(LogRecord record) {
    _items.insert(0, record);
    if (_items.length > capacity) {
      _items.removeRange(capacity, _items.length);
    }
  }

  /// Newest-first preload (e.g. bootstrap). Keeps at most [capacity].
  void preloadNewestFirst(Iterable<LogRecord> records) {
    _items.clear();
    for (final r in records) {
      if (_items.length >= capacity) break;
      _items.add(r);
    }
  }

  List<LogRecord> search({String? opId, int? rollcallId, String? query}) {
    final q = query?.trim().toLowerCase();
    return _items.where((r) {
      if (opId != null && opId.isNotEmpty && r.opId != opId) return false;
      if (rollcallId != null && r.rollcallId != rollcallId) return false;
      if (q != null && q.isNotEmpty) {
        final hay = '${r.opId ?? ''} ${r.rollcallId ?? ''} ${r.event} ${r.level}'
            .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList(growable: false);
  }
}
