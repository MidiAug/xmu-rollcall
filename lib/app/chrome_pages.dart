part of 'chrome.dart';

class SubpageScaffold extends StatelessWidget {
  const SubpageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.hasUnsavedChanges,
    this.isBusy,
  });
  final String title;
  final Widget body;
  final List<Widget>? actions;
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
      navigator.maybePop();
    }

    Widget child;
    if (PlatformHooks.isDesktop && !AppDensity.isTouch(context)) {
      final root = navigator == Navigator.of(context, rootNavigator: true);
      child = Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: p.canvas,
        body: Column(
          children: [
            if (root) const AppTitleBar(title: kAppDisplayName),
            Expanded(
              child: DesktopPage(
                title: title,
                onBack: navigator.canPop() ? back : null,
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
        backgroundColor: p.canvas,
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
                    height: 48,
                    child: Row(
                      children: [
                        if (navigator.canPop())
                          IconButton(
                            tooltip: '返回',
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
                              fontSize: 15,
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
        .copyWith(statusBarColor: Colors.transparent);
