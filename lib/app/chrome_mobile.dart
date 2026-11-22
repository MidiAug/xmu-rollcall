part of 'chrome.dart';

/// Shared geometry for touch pages, instead of per-page desktop miniatures.
abstract final class AppMobileUi {
  static const toolbarHeight = 56.0;
  static const target = 48.0;
  static const choiceRow = 56.0;
  static const inset = 16.0;
  static const panelRadius = AppRadii.card;

  /// Input presentation is independent of whether a layout has one or two panes.
  static bool useTouchChrome(BuildContext context) =>
      !PlatformHooks.isDesktop || AppDensity.isTouch(context);
}

class _ChoiceResult<T> {
  const _ChoiceResult(this.value);
  final T value;
}

/// One mobile selection surface for fields, filters and toolbar choices.
Future<_ChoiceResult<T>?> _showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> items,
  required T value,
  required String Function(T) labelOf,
  String Function(T)? trailingOf,
  IconData Function(T)? iconOf,
  Widget Function(T)? leadingOf,
  String Function(T)? subtitleOf,
  required ValueChanged<BuildContext> onPresented,
  required ValueChanged<bool> onPointerMode,
  bool pointerAutofocus = false,
  bool highlightSelection = false,
}) {
  final selectedAnchor = GlobalKey();
  return showModalBottomSheet<_ChoiceResult<T>>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      onPresented(sheetContext);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final selectedContext = selectedAnchor.currentContext;
        if (selectedContext != null && selectedContext.mounted) {
          Scrollable.ensureVisible(selectedContext, alignment: .4);
        }
      });
      final focus = FocusScope.of(sheetContext);
      return Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
          SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
          SingleActivator(LogicalKeyboardKey.arrowUp): PreviousFocusIntent(),
        },
        child: Actions(
          actions: {
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) {
                Navigator.pop(sheetContext);
                return null;
              },
            ),
            NextFocusIntent: CallbackAction<NextFocusIntent>(
              onInvoke: (_) {
                focus.nextFocus();
                return null;
              },
            ),
            PreviousFocusIntent: CallbackAction<PreviousFocusIntent>(
              onInvoke: (_) {
                focus.previousFocus();
                return null;
              },
            ),
          },
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent) onPointerMode(false);
              return KeyEventResult.ignored;
            },
            child: Listener(
              onPointerDown: (_) => onPointerMode(true),
              child: AppSheetFrame(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(sheetContext).height * .75,
                  ),
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: Theme.of(
                                  sheetContext,
                                ).textTheme.titleMedium?.copyWith(fontSize: 18),
                              ),
                            ),
                            const AppSheetCloseButton(),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < items.length; i++)
                                  KeyedSubtree(
                                    key: items[i] == value
                                        ? selectedAnchor
                                        : null,
                                    child: AppMenuOption(
                                      pointerAutofocus: pointerAutofocus,
                                      key: ValueKey('shell-select-option-$i'),
                                      label: labelOf(items[i]),
                                      trailing:
                                          trailingOf?.call(items[i]) ?? '',
                                      leadingIcon: iconOf?.call(items[i]),
                                      leading: leadingOf?.call(items[i]),
                                      subtitle: subtitleOf?.call(items[i]),
                                      selected: items[i] == value,
                                      highlightSelection: highlightSelection,
                                      showCheck: true,
                                      wrap: true,
                                      autofocus:
                                          items[i] == value ||
                                          (i == 0 && !items.contains(value)),
                                      onTap: () => Navigator.pop(
                                        sheetContext,
                                        _ChoiceResult(items[i]),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// A toolbar selection is text + disclosure, never a boxed form field.
class AppToolbarChoice<T> extends StatelessWidget {
  const AppToolbarChoice({
    super.key,
    required this.title,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.trailingOf,
    this.width = 112,
    this.expandLabel = false,
    this.height,
  });
  final String title;
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final String Function(T)? trailingOf;
  final ValueChanged<T>? onChanged;
  final double width;
  final bool expandLabel;
  final double? height;
  @override
  Widget build(BuildContext context) {
    final touch = AppMobileUi.useTouchChrome(context);
    final minHeight = height ?? (touch ? AppMobileUi.target : 36.0);
    return AppShellSelect<T>(
      value: value,
      items: items,
      labelOf: labelOf,
      onChanged: onChanged,
      semanticLabel: title,
      menuTrailingOf: trailingOf,
      width: width,
      alignMenuEnd: true,
      triggerBuilder: (context, open, toggle, focus) => TextButton(
        focusNode: focus,
        onPressed: toggle,
        style: TextButton.styleFrom(
          minimumSize: Size(0, minHeight),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          tapTargetSize: height != null || !touch
              ? MaterialTapTargetSize.shrinkWrap
              : MaterialTapTargetSize.padded,
          shape: const RoundedRectangleBorder(),
          backgroundColor: Colors.transparent,
        ),
        child: Row(
          mainAxisSize: expandLabel ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (expandLabel)
              Expanded(
                child: Text(
                  labelOf(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              Flexible(
                child: Text(
                  labelOf(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(width: 4),
            const Icon(AppIcons.down, size: 14),
          ],
        ),
      ),
    );
  }
}
