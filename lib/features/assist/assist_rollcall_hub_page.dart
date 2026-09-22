import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_list_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';

/// Per-assist pending rollcall hub: same list + poll UX as owner, page-scoped timer.
class AssistRollcallHubPage extends ConsumerStatefulWidget {
  const AssistRollcallHubPage({super.key, required this.identity});

  final AssistIdentity identity;

  @override
  ConsumerState<AssistRollcallHubPage> createState() =>
      _AssistRollcallHubPageState();
}

class _AssistRollcallHubPageState extends ConsumerState<AssistRollcallHubPage> {
  late final AssistPageMonitor _monitor;
  String? _bootError;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _monitor = AssistPageMonitor(
      refresh: () => ref
          .read(activeRollcallsProvider(widget.identity.userId).notifier)
          .refresh(),
      readList: () =>
          ref.read(activeRollcallsProvider(widget.identity.userId)).valueOrNull ??
          const [],
      readConfig: () => ref.read(monitorControllerProvider).config,
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final svc = await ref.read(assistServiceProvider.future);
      await svc.ensureSession(widget.identity);
      await ref
          .read(activeRollcallsProvider(widget.identity.userId).notifier)
          .refresh();
      if (!mounted) return;
      setState(() {
        _ready = true;
        _bootError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ready = true;
        _bootError = '$e';
      });
    }
  }

  @override
  void dispose() {
    _monitor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.shellBreakpoint;
    final id = widget.identity;

    return SubpageScaffold(
      title: id.displayName,
      actions: [
        if (_ready && _bootError == null)
          AppRefreshButton(
            visualDensity: VisualDensity.compact,
            color: p.muted,
            onRefresh: () => ref
                .read(activeRollcallsProvider(id.userId).notifier)
                .refresh(),
          ),
      ],
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : _bootError != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '无法加载协助会话',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_bootError!, style: TextStyle(color: p.muted)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _ready = false;
                            _bootError = null;
                          });
                          _bootstrap();
                        },
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : AppContentColumn(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpace.pageXOf(context),
                          wide ? AppSpace.xxs : AppSpace.xxs,
                          AppSpace.pageXOf(context),
                          AppSpace.sm,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _AssistPollQuickBar(monitor: _monitor),
                            ),
                            Text(
                              id.kind.labelZh,
                              style: TextStyle(fontSize: 12, color: p.muted),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: RollcallListPage(
                          embedded: true,
                          assistUserId: id.userId,
                          enableAssistMulti: false,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

/// Page-local poller: shares interval prefs with owner monitor, independent timer.
class AssistPageMonitor {
  AssistPageMonitor({
    required this.refresh,
    required this.readList,
    required this.readConfig,
    required this.onChanged,
  });

  final Future<void> Function() refresh;
  final List<RollcallItem> Function() readList;
  final MonitorConfig Function() readConfig;
  final VoidCallback onChanged;

  Timer? _timer;
  bool running = false;
  DateTime? nextPollAt;
  int consecutiveFailures = 0;

  void start() {
    if (running) return;
    running = true;
    consecutiveFailures = 0;
    onChanged();
    _schedule(immediate: true);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    running = false;
    nextPollAt = null;
    onChanged();
  }

  void pollNow() {
    if (!running) return;
    _schedule(immediate: true);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  void _schedule({bool immediate = false}) {
    _timer?.cancel();
    if (!running) return;
    final config = readConfig();
    final failures = consecutiveFailures;
    final backoffFactor = failures == 0 ? 1 : (1 << (failures.clamp(0, 4)));
    var delay = immediate ? Duration.zero : config.nextDelay();
    if (!immediate && failures > 0) {
      delay = Duration(seconds: delay.inSeconds * backoffFactor);
    }
    nextPollAt = DateTime.now().add(delay);
    onChanged();
    _timer = Timer(delay, _tick);
  }

  Future<void> _tick() async {
    if (!running) return;
    try {
      await refresh();
      final list = readList();
      if (list.isNotEmpty) {
        _timer?.cancel();
        _timer = null;
        running = false;
        nextPollAt = null;
        consecutiveFailures = 0;
        onChanged();
        return;
      }
      consecutiveFailures = 0;
    } catch (_) {
      consecutiveFailures += 1;
    }
    onChanged();
    _schedule();
  }
}

class _AssistPollQuickBar extends StatefulWidget {
  const _AssistPollQuickBar({required this.monitor});

  final AssistPageMonitor monitor;

  @override
  State<_AssistPollQuickBar> createState() => _AssistPollQuickBarState();
}

class _AssistPollQuickBarState extends State<_AssistPollQuickBar> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (widget.monitor.running) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final m = widget.monitor;

    if (!m.running) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: m.start,
          icon: Icon(Icons.radar_outlined, size: 18, color: p.primary),
          label: Text(
            '开始检测',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: p.primary,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            visualDensity: VisualDensity.compact,
          ),
        ),
      );
    }

    final next = m.nextPollAt;
    final secs = next == null
        ? 0
        : next.difference(DateTime.now()).inSeconds.clamp(0, 9999);

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: p.selected,
            borderRadius: BorderRadius.circular(AppRadii.control),
            child: InkWell(
              onTap: m.pollNow,
              borderRadius: BorderRadius.circular(AppRadii.control),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  '检测中 · ${secs}s',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: '停止检测',
            visualDensity: VisualDensity.compact,
            onPressed: m.stop,
            icon: Icon(Icons.stop_circle_outlined, color: p.muted, size: 22),
          ),
        ],
      ),
    );
  }
}
