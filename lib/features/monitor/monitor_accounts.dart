part of 'monitor_controller.dart';

/// Monitor engines belong to credential accounts, independently of the visible page.
final accountMonitorProvider =
    StateNotifierProvider.family<MonitorController, MonitorState, int?>(
      (ref, scope) =>
          MonitorController(ref, fixedAccount: true, accountScope: scope),
    );

final accountMonitorStatesProvider = Provider<Map<int?, MonitorState>>((ref) {
  final identities = ref.watch(assistControllerProvider).identities;
  return {
    for (final scope in <int?>[null, ...identities.map((a) => a.userId)])
      scope: ref.watch(accountMonitorProvider(scope)),
  };
});

/// Window close and sign-out must include tasks belonging to hidden accounts.
final globalMonitorStateProvider = Provider<MonitorState>((ref) {
  final selected = ref.watch(monitorControllerProvider);
  final states = ref.watch(accountMonitorStatesProvider).values;
  return states.where((s) => s.running).firstOrNull ?? selected;
});

class _SelectedMonitorController extends MonitorController {
  _SelectedMonitorController(Ref ref) : super(ref, bootstrap: false) {
    _select(null);
    _select(_scope);
    ref.listen(selectedRollcallAccountProvider, (_, next) {
      _select(next);
    });
  }

  @override
  Future<void> stopAllAsync({String reason = 'user_stop'}) async {
    final scopes = <int?>{
      null,
      ..._observed,
      ..._ref.read(assistControllerProvider).identities.map((a) => a.userId),
    };
    final stops = [
      for (final scope in scopes)
        _ref
            .read(accountMonitorProvider(scope).notifier)
            .stopAsync(reason: reason),
    ];
    await Future.wait(stops);
    if (PlatformHooks.isAndroid) {
      await AndroidMonitorShell.instance.stopOngoing(reason: reason);
    }
  }

  final _observed = <int?>{};
  MonitorController get _selected =>
      _ref.read(accountMonitorProvider(_scope).notifier);

  void _select(int? scope) {
    state = _ref.read(accountMonitorProvider(scope));
    if (_observed.add(scope)) {
      _ref.listen(accountMonitorProvider(scope), (_, next) {
        if (_scope == scope) state = next;
      });
    }
  }

  @override
  void commitPersist() => _selected.commitPersist();
  @override
  void setPreset(MonitorPreset preset) => _selected.setPreset(preset);
  @override
  void setIntervalSeconds(int seconds) => _selected.setIntervalSeconds(seconds);
  @override
  void setJitterRatio(double ratio) => _selected.setJitterRatio(ratio);
  @override
  void setAttendanceIntervalSeconds(int seconds) =>
      _selected.setAttendanceIntervalSeconds(seconds);
  @override
  void start() => _selected.start();
  @override
  void setAutomaticAnswer(bool value) => _selected.setAutomaticAnswer(value);
  @override
  void setCourseWatch(bool value) => _selected.setCourseWatch(value);
  @override
  void setResumeWatch(bool value) => _selected.setResumeWatch(value);
  @override
  void setCompleteProbe(bool value) => _selected.setCompleteProbe(value);
  @override
  void setAnswerWaitMode(AnswerWaitMode mode) =>
      _selected.setAnswerWaitMode(mode);
  @override
  void setAnswerWaitValue(int value) => _selected.setAnswerWaitValue(value);
  @override
  Future<StartMonitorResult> startAsync() => _selected.startAsync();
  @override
  void stop({String reason = 'user_stop'}) => _selected.stop(reason: reason);
  @override
  void pollNow({bool manual = true}) => _selected.pollNow(manual: manual);
  @override
  Future<void> stopAsync({String reason = 'user_stop'}) =>
      _selected.stopAsync(reason: reason);
  @override
  void debugArmRunning() => _selected.debugArmRunning();
  @override
  void debugScheduleDiscovery({
    Duration delay = const Duration(seconds: 10),
    int count = 1,
  }) => _selected.debugScheduleDiscovery(delay: delay, count: count);
  @override
  void debugCancelScheduledDiscovery() =>
      _selected.debugCancelScheduledDiscovery();
}
