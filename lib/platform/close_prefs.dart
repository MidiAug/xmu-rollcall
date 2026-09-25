/// Desktop close-window preference (aligned with xmu-sports ShellPrefs).
enum CloseMode {
  ask,
  tray,
  quit,
}

extension CloseModeX on CloseMode {
  String get label => switch (this) {
        CloseMode.ask => '每次询问',
        CloseMode.tray => '最小化到托盘',
        CloseMode.quit => '退出应用',
      };
}

class ClosePrefs {
  const ClosePrefs({
    this.closeToTray = true,
    this.closePrefSet = false,
    this.closeRememberDefaultUsed = false,
  });

  final bool closeToTray;
  final bool closePrefSet;
  final bool closeRememberDefaultUsed;

  CloseMode get mode {
    if (!closePrefSet) return CloseMode.ask;
    return closeToTray ? CloseMode.tray : CloseMode.quit;
  }

  /// Default-check「记住我的选择」only for the first ask in the install lifetime.
  bool get rememberCheckboxDefault => !closeRememberDefaultUsed;

  ClosePrefs copyWith({
    bool? closeToTray,
    bool? closePrefSet,
    bool? closeRememberDefaultUsed,
  }) {
    return ClosePrefs(
      closeToTray: closeToTray ?? this.closeToTray,
      closePrefSet: closePrefSet ?? this.closePrefSet,
      closeRememberDefaultUsed:
          closeRememberDefaultUsed ?? this.closeRememberDefaultUsed,
    );
  }

  static ClosePrefs fromMode(CloseMode mode, {required bool rememberUsed}) {
    return switch (mode) {
      CloseMode.ask => ClosePrefs(
          closeToTray: true,
          closePrefSet: false,
          closeRememberDefaultUsed: rememberUsed,
        ),
      CloseMode.tray => ClosePrefs(
          closeToTray: true,
          closePrefSet: true,
          closeRememberDefaultUsed: rememberUsed,
        ),
      CloseMode.quit => ClosePrefs(
          closeToTray: false,
          closePrefSet: true,
          closeRememberDefaultUsed: rememberUsed,
        ),
    };
  }

  /// After user picks tray/quit from the ask dialog.
  ClosePrefs afterAskChoice({
    required bool toTray,
    required bool remember,
  }) {
    return ClosePrefs(
      closeToTray: toTray,
      closePrefSet: remember,
      closeRememberDefaultUsed: true,
    );
  }
}
