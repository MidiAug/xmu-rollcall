part of 'chrome.dart';

class SubpageScaffold extends StatelessWidget {
  const SubpageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.onBack,
    this.hasUnsavedChanges,
    this.isBusy,
  });
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final bool Function()? hasUnsavedChanges;
  final bool Function()? isBusy;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    void back() {
      if (!context.mounted ||
          (route != null && (!route.isCurrent || !route.isActive))) {
        return;
      }
      if (onBack != null) {
        onBack!();
      } else {
        navigator.maybePop();
      }
    }

    Widget child;
    if (PlatformHooks.isDesktop && !AppMobileUi.useTouchChrome(context)) {
      final root = navigator == Navigator.of(context, rootNavigator: true);
      child = Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: p.pageBackground(context),
        body: Column(
          children: [
            if (root) const AppTitleBar(title: kAppDisplayName),
            Expanded(
              child: DesktopPage(
                title: title,
                onBack: onBack != null || navigator.canPop() ? back : null,
                actions: actions ?? const [],
                child: body,
              ),
            ),
          ],
        ),
      );
    } else {
      child = Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: p.pageBackground(context),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnnotatedRegion<SystemUiOverlayStyle>(
              value: _overlayForSurface(p.surface),
              child: ColoredBox(
                color: p.surface,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.viewPaddingOf(context).top,
                  ),
                  child: SizedBox(
                    height: AppMobileUi.toolbarHeight,
                    child: Row(
                      children: [
                        if (onBack != null || navigator.canPop())
                          AppIconButton(
                            tooltip: '返回',
                            extent: 48,
                            onPressed: back,
                            icon: const Icon(AppIcons.back),
                          )
                        else
                          const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: p.ink,
                            ),
                          ),
                        ),
                        ...?actions,
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }
    if (hasUnsavedChanges == null && isBusy == null) return child;
    return ShellTabExitGuard(
      hasUnsavedChanges: hasUnsavedChanges,
      isBusy: isBusy,
      child: child,
    );
  }
}

SystemUiOverlayStyle _overlayForSurface(Color surface) =>
    (ThemeData.estimateBrightnessForColor(surface) == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark)
        .copyWith(
          statusBarColor: Colors.transparent,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
          systemNavigationBarIconBrightness:
              ThemeData.estimateBrightnessForColor(surface) == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        );
