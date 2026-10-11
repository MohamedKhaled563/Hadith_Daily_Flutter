import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// In-memory "this collection just changed" signal shared by every tab.
///
/// Tabs live in an IndexedStack and stay mounted, so a page that loads its
/// list once (a one-shot `get()`) never sees what another tab writes — an
/// upload from تعديل بالجملة used to need a full browser refresh before the
/// pool tab showed it. Writers call [markChanged] after committing; pages
/// using [DashboardAutoRefresh] reload.
///
/// Deliberately not a Firestore listener on the collections themselves:
/// every device bumps `timesShown` on dailyMessages when it draws a
/// message, so a live listener would re-read (and bill) docs all day long
/// for changes the dashboard doesn't care about.
class DashboardRefresh extends ChangeNotifier {
  DashboardRefresh._();

  static final instance = DashboardRefresh._();

  final _revisions = <String, int>{};

  int revisionOf(String collection) => _revisions[collection] ?? 0;

  static void markChanged(Iterable<String> collections) {
    final self = instance;
    var changed = false;
    for (final c in collections) {
      self._revisions[c] = self.revisionOf(c) + 1;
      changed = true;
    }
    if (changed) self.notifyListeners();
  }
}

/// Keeps a tab's one-shot list in step with [DashboardRefresh] without
/// hammering Firestore:
///
/// - a change to a [watchedCollections] entry marks the page dirty; it
///   reloads only while it is the visible tab (hidden tabs wait until shown,
///   so an upload doesn't trigger reloads on pages nobody is looking at);
/// - bursts (an upload commits several 400-op batches) are coalesced by a
///   short debounce, and a change arriving mid-load queues exactly one
///   follow-up load instead of overlapping requests;
/// - showing a tab whose data is older than [staleAfter] reloads it too,
///   which picks up changes made from another browser or by another admin.
///
/// Reloads are silent: [loadData] swaps the new list in when it arrives,
/// so the old one stays on screen (and scroll position is kept) meanwhile.
mixin DashboardAutoRefresh<T extends StatefulWidget> on State<T> {
  Set<String> get watchedCollections;

  Duration get staleAfter => const Duration(minutes: 1);

  /// Fetch and apply fresh data. Throwing is fine — [refreshing] is cleared
  /// and the error is handed to [onRefreshError].
  Future<void> loadData();

  void onRefreshError(Object error) {}

  bool get refreshing => _inFlight;

  final _seenRevisions = <String, int>{};
  ValueListenable<TickerModeData>? _visible;
  Timer? _debounce;
  DateTime? _loadedAt;
  bool _dirty = false;
  bool _inFlight = false;

  bool get _isVisible => _visible?.value.enabled ?? true;

  @override
  void initState() {
    super.initState();
    for (final c in watchedCollections) {
      _seenRevisions[c] = DashboardRefresh.instance.revisionOf(c);
    }
    DashboardRefresh.instance.addListener(_onBusChanged);
    refreshNow();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The dashboard wraps each hidden tab in TickerMode(enabled: false);
    // the notifier lets us react to the tab being shown without making
    // this State rebuild on every TickerMode change.
    final visible = TickerMode.getValuesNotifier(context);
    if (!identical(visible, _visible)) {
      _visible?.removeListener(_onVisibilityChanged);
      _visible = visible..addListener(_onVisibilityChanged);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _visible?.removeListener(_onVisibilityChanged);
    DashboardRefresh.instance.removeListener(_onBusChanged);
    super.dispose();
  }

  void _onBusChanged() {
    var touched = false;
    for (final c in watchedCollections) {
      final rev = DashboardRefresh.instance.revisionOf(c);
      if (rev != _seenRevisions[c]) {
        _seenRevisions[c] = rev;
        touched = true;
      }
    }
    if (!touched) return;
    _dirty = true;
    if (_isVisible) _scheduleRefresh();
  }

  void _onVisibilityChanged() {
    if (!_isVisible) return;
    final loadedAt = _loadedAt;
    final stale =
        loadedAt != null && DateTime.now().difference(loadedAt) > staleAfter;
    if (_dirty || stale) _scheduleRefresh();
  }

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), refreshNow);
  }

  /// Load now (the manual refresh button), or right after the load already
  /// in flight if there is one.
  Future<void> refreshNow() async {
    _debounce?.cancel();
    if (_inFlight) {
      _dirty = true;
      return;
    }
    _dirty = false;
    setState(() => _inFlight = true);
    try {
      await loadData();
      _loadedAt = DateTime.now();
    } catch (e) {
      if (mounted) onRefreshError(e);
    } finally {
      if (mounted) {
        setState(() => _inFlight = false);
        if (_dirty && _isVisible) _scheduleRefresh();
      }
    }
  }
}
