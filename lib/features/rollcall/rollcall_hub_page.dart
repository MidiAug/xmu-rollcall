import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/history/history_page.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/settings/notification_settings_page.dart';
import 'package:xmu_rollcall/features/monitor/monitor_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_list_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';

/// 签到 Tab：进行中列表为主；轮询为快开子功能 + 二级设置；记录为二级页。
class RollcallHubPage extends ConsumerStatefulWidget {
  const RollcallHubPage({super.key});

  @override
  ConsumerState<RollcallHubPage> createState() => _RollcallHubPageState();
}

class _RollcallHubPageState extends ConsumerState<RollcallHubPage>
    with ShellTabAware<RollcallHubPage>, WidgetsBindingObserver {
  final _scroll = ScrollController();
  int? get _assistUserId => ref.read(selectedRollcallAccountProvider);
  bool _switching = false;
  String? _switchError;
  int _switchRevision = 0;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _confirmOnAppear() {
    if (!mounted ||
        !_visible ||
        _switching ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed) ||
        !ref.read(authControllerProvider).isSignedIn) {
      return;
    }
    unawaited(
      ref
          .read(activeRollcallsProvider(_assistUserId).notifier)
          .ensureFreshOnAppear(),
    );
  }

  @override
  void onShellTabVisible() {
    _visible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _confirmOnAppear());
  }

  @override
  void onShellTabHidden() {
    _visible = false;
    super.onShellTabHidden();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _confirmOnAppear();
  }

  Future<void> _selectIdentity(int value) async {
    final id = value == 0 ? null : value;
    final revision = ++_switchRevision;
    setState(() {
      ref.read(selectedRollcallAccountProvider.notifier).state = id;
      _switching = id != null;
      _switchError = null;
    });
    AppLog.event(
      'rollcall.identity.switch',
      fields: {'session': id == null ? 'owner' : 'assist', 'assistUserId': ?id},
    );
    if (id == null) return;
    try {
      final identity = ref
          .read(assistControllerProvider)
          .identities
          .firstWhere((e) => e.userId == id);
      final service = await ref.read(assistServiceProvider.future);
      await service.ensureSession(identity);
      if (!mounted || revision != _switchRevision) return;
      // Reload even when this identity already has a cached list.
      await ref.read(activeRollcallsProvider(id).notifier).refresh();
    } catch (error, stack) {
      AppLog.logAppError(
        error: error,
        stackTrace: stack,
        source: 'rollcall.identity.switch',
      );
      if (!mounted || revision != _switchRevision) return;
      setState(() => _switchError = '无法加载该身份，请重试');
    } finally {
      if (mounted && revision == _switchRevision) {
        setState(() => _switching = false);
      }
    }
  }

  @override
  AppDestination get shellTab => AppDestination.rollcall;

  @override
  ScrollController? get shellScrollController => _scroll;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  void _openSettings(BuildContext context) {
    AppPageRoutes.push(context, const MonitorSettingsPage());
  }

  void _openHistory(BuildContext context) {
    AppPageRoutes.push(context, const HistoryPage());
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.shellBreakpoint;
    final p = AppPalette.of(context);
    final auth = ref.watch(authControllerProvider);
    final roster = ref.watch(assistControllerProvider).identities;
    final selected = ref.watch(selectedRollcallAccountProvider);
    final scope = roster.any((e) => e.userId == selected) ? selected : null;
    DateTime? updatedAt;
    var confirming = false;
    if (auth.isSignedIn && !_switching && _switchError == null) {
      confirming = ref.watch(activeRollcallsProvider(scope)).isLoading;
      updatedAt = ref
          .read(activeRollcallsProvider(scope).notifier)
          .lastUpdatedAt;
    }
    final updatedLabel = _switching
        ? '正在切换…'
        : confirming
        ? '正在确认最新状态…'
        : updatedAt == null
        ? '下拉刷新签到'
        : '更新于 ${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')}';
    ref.listen(authControllerProvider.select((state) => state.profile?.id), (
      previous,
      next,
    ) {
      if (previous == next) return;
      _switchRevision++;
      setState(() {
        _switching = false;
        _switchError = null;
      });
    });
    ref.listen(assistControllerProvider, (previous, next) {
      if (next.ready &&
          _assistUserId != null &&
          !next.identities.any((e) => e.userId == _assistUserId)) {
        _switchRevision++;
        setState(() {
          ref.read(selectedRollcallAccountProvider.notifier).state = null;
          _switching = false;
          _switchError = null;
        });
      }
    });

    return PageScaffold(
      title: '签到',
      showHeader: false,
      child: AppContentColumn(
        child: PrimaryScrollController(
          controller: _scroll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpace.pageXOf(context),
                  wide ? AppSpace.sm : AppSpace.xs,
                  AppSpace.pageXOf(context),
                  AppSpace.sm,
                ),
                child: DecoratedBox(
                  key: const ValueKey('rollcall-toolbar'),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: p.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _IdentityMenu(
                                value: scope ?? 0,
                                identities: roster,
                                ownerName: auth.profile?.name ?? '我',
                                onChanged: _selectIdentity,
                              ),
                            ),
                            const SizedBox(width: 4),
                            AppRefreshButton(
                              visualDensity: VisualDensity.compact,
                              color: p.muted,
                              iconSize: 20,
                              onRefresh: () async {
                                if (_switching) return;
                                if (_switchError != null) {
                                  await _selectIdentity(scope ?? 0);
                                } else {
                                  await ref
                                      .read(
                                        activeRollcallsProvider(scope).notifier,
                                      )
                                      .refresh();
                                }
                              },
                            ),
                            IconButton(
                              tooltip: '自动检测设置',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _openSettings(context),
                              icon: Icon(
                                Icons.tune_rounded,
                                color: p.muted,
                                size: 20,
                              ),
                            ),
                            IconButton(
                              tooltip: '签到记录',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _openHistory(context),
                              icon: Icon(
                                Icons.history_rounded,
                                color: p.muted,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                updatedLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: p.muted),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const _PollQuickBar(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _switching
                    ? const Center(child: CircularProgressIndicator())
                    : _switchError != null
                    ? EmptyHint(
                        icon: Icons.person_outline,
                        title: _switchError!,
                        action: TextButton(
                          onPressed: () => _selectIdentity(scope ?? 0),
                          child: const Text('重试'),
                        ),
                      )
                    : RollcallListPage(
                        key: ValueKey(scope),
                        embedded: true,
                        showUpdatedAt: false,
                        assistUserId: scope,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentityMenu extends StatelessWidget {
  const _IdentityMenu({
    required this.value,
    required this.identities,
    required this.ownerName,
    required this.onChanged,
  });
  final int value;
  final List<AssistIdentity> identities;
  final String ownerName;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final name = value == 0
        ? ownerName
        : identities.firstWhere((e) => e.userId == value).displayName;
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: p.selected, shape: BoxShape.circle),
          child: Icon(Icons.person_outline_rounded, size: 18, color: p.primary),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: AppTruncatedText(
            name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: p.ink,
            ),
          ),
        ),
        if (identities.isNotEmpty) ...[
          const SizedBox(width: 4),
          Icon(Icons.unfold_more_rounded, size: 16, color: p.muted),
        ],
      ],
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: PopupMenuButton<int>(
          key: const ValueKey('rollcall-identity-menu'),
          enabled: identities.isNotEmpty,
          tooltip: '',
          position: PopupMenuPosition.under,
          offset: const Offset(0, 6),
          color: p.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          constraints: const BoxConstraints(
            minWidth: 180,
            maxWidth: 220,
            maxHeight: 280,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: p.border),
          ),
          onSelected: (id) {
            if (id != value) onChanged(id);
          },
          itemBuilder: (context) => [
            for (final entry in [
              (id: 0, name: ownerName),
              for (final identity in identities)
                (id: identity.userId, name: identity.displayName),
            ])
              _IdentityMenuItem(
                value: entry.id,
                name: entry.name,
                selected: entry.id == value,
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
            child: label,
          ),
        ),
      ),
    );
  }
}

/// Keep hover/focus paint inside the same inset rounded row as filters,
/// while retaining PopupMenuButton's route and keyboard selection behavior.
class _IdentityMenuItem extends PopupMenuItem<int> {
  const _IdentityMenuItem({
    required int value,
    required this.name,
    required this.selected,
  }) : super(value: value, height: 44, child: const SizedBox.shrink());

  final String name;
  final bool selected;

  @override
  PopupMenuItemState<int, _IdentityMenuItem> createState() =>
      _IdentityMenuItemState();
}

class _IdentityMenuItemState
    extends PopupMenuItemState<int, _IdentityMenuItem> {
  @override
  Widget build(BuildContext context) => buildSemantics(
    child: SizedBox(
      // PopupMenu measures intrinsic widths before layout; keep the text
      // overflow measurement behind a finite row width.
      width: 180,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: widget.height),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: AppMenuOption(
            label: widget.name,
            selected: widget.selected,
            showCheck: true,
            onTap: handleTap,
          ),
        ),
      ),
    ),
  );
}

/// Idle: 「开始检测」pill. Running: capsule with countdown (tap = pollNow) + stop.
class _PollQuickBar extends ConsumerStatefulWidget {
  const _PollQuickBar();

  @override
  ConsumerState<_PollQuickBar> createState() => _PollQuickBarState();
}

class _PollQuickBarState extends ConsumerState<_PollQuickBar> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (ref.read(monitorControllerProvider).running) setState(() {});
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
    final monitor = ref.watch(monitorControllerProvider);
    final ctrl = ref.read(monitorControllerProvider.notifier);
    final signedIn = ref.watch(authControllerProvider).isSignedIn;

    if (!monitor.running) {
      final enabled = signedIn && !monitor.starting && !monitor.loadingSettings;
      return Align(
        alignment: Alignment.centerLeft,
        child: AppTooltipAnchor(
          child: Tooltip(
            message: enabled || monitor.starting ? '' : '请先登录',
            child: AppQuietPill(
              onTap: enabled
                  ? () async {
                      final r = await ctrl.startAsync();
                      if (!context.mounted) return;
                      switch (r) {
                        case StartMonitorResult.started:
                          await showBackgroundReminderSetup(context);
                        case StartMonitorResult.notificationDenied:
                          AppToast.show(context, '需要通知权限才能在后台检测', error: true);
                          await showBackgroundReminderSetup(context);
                        case StartMonitorResult.fgsFailed:
                          AppToast.show(context, '无法启动后台检测通知', error: true);
                        default:
                          break;
                      }
                    }
                  : null,
              background: enabled ? p.selected : p.surfaceHigh,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.radar_outlined,
                    size: 16,
                    color: enabled ? p.primary : p.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    monitor.starting ? '启动中…' : '开始检测',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: enabled ? p.primary : p.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final next = monitor.nextPollAt;
    final secs = next == null
        ? 0
        : next.difference(DateTime.now()).inSeconds.clamp(0, 9999);
    final failed = monitor.consecutiveFailures > 0;
    final label = failed ? '重试中  ${secs}s' : '检测中  ${secs}s';

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTooltipAnchor(
            child: Tooltip(
              message: failed ? '上次检测失败，点击立即重试' : '立即检测一次',
              child: AppQuietPill(
                onTap: ctrl.pollNow,
                background: failed
                    ? p.danger.withValues(alpha: 0.12)
                    : p.selected,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    color: failed ? p.danger : p.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          AppTooltipAnchor(
            child: IconButton(
              tooltip: '停止检测',
              visualDensity: VisualDensity.compact,
              onPressed: ctrl.stop,
              icon: Icon(Icons.stop_circle_outlined, color: p.muted, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
