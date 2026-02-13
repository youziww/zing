import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/deck_provider.dart';
import '../providers/stats_provider.dart';
import '../models/deck.dart';
import '../services/import_service.dart';
import 'study_screen.dart';
import 'card_editor_screen.dart';
import 'browser_screen.dart';
import 'stats_screen.dart';
import 'deck_options_screen.dart';

class DeckListScreen extends ConsumerWidget {
  const DeckListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decksAsync = ref.watch(deckListProvider);
    final todayStats = ref.watch(todayStatsProvider);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Zing', style: TextStyle(fontWeight: FontWeight.w700)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.chart_bar, size: 22),
              onPressed: () => Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const StatsScreen()),
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.search, size: 22),
              onPressed: () => Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const BrowserScreen()),
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Today's stats card
            todayStats.when(
              data: (stats) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: CupertinoColors.secondarySystemGroupedBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatChip(
                        label: 'Today',
                        value: '${stats.reviewCount}',
                        icon: CupertinoIcons.bolt_fill,
                        color: CupertinoColors.systemBlue,
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: CupertinoColors.separator,
                      ),
                      _StatChip(
                        label: 'Accuracy',
                        value: stats.reviewCount > 0
                            ? '${(stats.accuracy * 100).toStringAsFixed(0)}%'
                            : '--',
                        icon: CupertinoIcons.checkmark_seal_fill,
                        color: CupertinoColors.systemGreen,
                      ),
                    ],
                  ),
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            // Deck list
            Expanded(
              child: decksAsync.when(
                data: (decks) => decks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.rectangle_stack,
                                size: 48, color: CupertinoColors.systemGrey3),
                            const SizedBox(height: 12),
                            const Text(
                              'No decks yet',
                              style: TextStyle(
                                color: CupertinoColors.systemGrey,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Create a deck or import from .apkg',
                              style: TextStyle(
                                color: CupertinoColors.systemGrey2,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildDeckList(decks),
                loading: () =>
                    const Center(child: CupertinoActivityIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
            // Bottom action bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
                border: const Border(
                  top: BorderSide(color: CupertinoColors.separator, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      borderRadius: BorderRadius.circular(10),
                      child: const Text('Add Deck', style: TextStyle(fontWeight: FontWeight.w600)),
                      onPressed: () => _showAddDeckDialog(context, ref),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: CupertinoColors.systemOrange,
                      borderRadius: BorderRadius.circular(10),
                      child: const Text('Import',
                          style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w600)),
                      onPressed: () => _importApkg(context, ref),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeckList(List<Deck> decks) {
    // Group decks: top-level parents and their children
    final topLevel = <Deck>[];
    final children = <String, List<Deck>>{};
    final topLevelNames = <String>{};

    for (final deck in decks) {
      if (deck.depth == 0) {
        topLevel.add(deck);
        topLevelNames.add(deck.name);
      } else {
        final rootName = deck.name.split('::').first;
        children.putIfAbsent(rootName, () => []).add(deck);
      }
    }

    // Create virtual parents for orphaned child groups
    for (final rootName in children.keys) {
      if (!topLevelNames.contains(rootName)) {
        // Find the shallowest child to use as the virtual parent
        final orphans = children[rootName]!;
        orphans.sort((a, b) => a.depth.compareTo(b.depth));
        final virtualParent = orphans.removeAt(0);
        topLevel.add(virtualParent);
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: topLevel.length,
      itemBuilder: (context, index) {
        final parent = topLevel[index];
        final rootName = parent.name.split('::').first;
        final subs = children[rootName] ?? [];
        return _DeckSection(parent: parent, children: subs);
      },
    );
  }

  void _showAddDeckDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('New Deck'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Deck name',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text('Create'),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(deckListProvider.notifier).addDeck(name);
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _importApkg(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.first.path;
    if (filePath == null) return;

    if (!context.mounted) return;

    // Show loading
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        content: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoActivityIndicator(),
              SizedBox(height: 12),
              Text('Importing...'),
            ],
          ),
        ),
      ),
    );

    try {
      final service = ImportService();
      final importResult = await service.importApkg(filePath);
      if (!context.mounted) return;
      Navigator.pop(context); // dismiss loading

      ref.read(deckListProvider.notifier).refresh();

      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Import Complete'),
          content: Text(
            'Imported ${importResult.notesImported} notes, '
            '${importResult.cardsImported} cards.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // dismiss loading
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Import Failed'),
          content: Text('$e'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }
}

class _DeckSection extends ConsumerStatefulWidget {
  final Deck parent;
  final List<Deck> children;

  const _DeckSection({required this.parent, required this.children});

  @override
  ConsumerState<_DeckSection> createState() => _DeckSectionState();
}

class _DeckSectionState extends ConsumerState<_DeckSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final hasChildren = widget.children.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemGroupedBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DeckRow(
              deck: widget.parent,
              isParent: hasChildren,
              isFirst: true,
              isLast: !hasChildren || !_expanded,
              expanded: _expanded,
              onToggleExpand: hasChildren
                  ? () => setState(() => _expanded = !_expanded)
                  : null,
            ),
            if (_expanded)
              for (int i = 0; i < widget.children.length; i++)
                _DeckRow(
                  deck: widget.children[i],
                  isParent: false,
                  isFirst: false,
                  isLast: i == widget.children.length - 1,
                ),
          ],
        ),
      ),
    );
  }
}

class _DeckRow extends ConsumerWidget {
  final Deck deck;
  final bool isParent;
  final bool isFirst;
  final bool isLast;
  final bool expanded;
  final VoidCallback? onToggleExpand;

  const _DeckRow({
    required this.deck,
    required this.isParent,
    required this.isFirst,
    required this.isLast,
    this.expanded = false,
    this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDue = deck.totalDueCount > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isFirst)
          Padding(
            padding: EdgeInsets.only(left: isParent ? 16 : 44),
            child: Container(height: 0.5, color: CupertinoColors.separator),
          ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (onToggleExpand != null) {
              onToggleExpand!();
            } else if (hasDue) {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => StudyScreen(deckId: deck.id, deckName: deck.name),
                ),
              ).then((_) => ref.read(deckListProvider.notifier).refresh());
            }
          },
          onLongPress: () => _showContextMenu(context, ref),
          child: Padding(
            padding: EdgeInsets.only(
              left: isParent ? 16 : 44,
              right: 16,
              top: isParent ? 14 : 12,
              bottom: isParent ? 14 : 12,
            ),
            child: Row(
              children: [
                if (onToggleExpand != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      expanded ? CupertinoIcons.chevron_down : CupertinoIcons.chevron_right,
                      size: 14,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                Expanded(
                  child: Text(
                    deck.shortName,
                    style: TextStyle(
                      fontSize: isParent ? 17 : 16,
                      fontWeight: isParent ? FontWeight.w600 : FontWeight.normal,
                      color: CupertinoColors.label,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                _CountBadge(count: deck.newCount, color: CupertinoColors.systemBlue),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('·', style: TextStyle(color: CupertinoColors.systemGrey3, fontSize: 14)),
                ),
                _CountBadge(count: deck.learnCount, color: CupertinoColors.systemRed),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('·', style: TextStyle(color: CupertinoColors.systemGrey3, fontSize: 14)),
                ),
                _CountBadge(count: deck.reviewCount, color: CupertinoColors.systemGreen),
                if (hasDue && onToggleExpand == null)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(CupertinoIcons.chevron_right,
                        size: 14, color: CupertinoColors.systemGrey3),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showContextMenu(BuildContext context, WidgetRef ref) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(deck.name),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Add Cards'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => CardEditorScreen(deckId: deck.id),
                ),
              ).then((_) => ref.read(deckListProvider.notifier).refresh());
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Browse Cards'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => BrowserScreen(deckId: deck.id),
                ),
              );
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Options'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => DeckOptionsScreen(deckId: deck.id),
                ),
              );
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Rename'),
            onPressed: () {
              Navigator.pop(context);
              _showRenameDialog(context, ref);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              Navigator.pop(context);
              _confirmDelete(context, ref);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: deck.name);
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Rename Deck'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text('Rename'),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref
                    .read(deckListProvider.notifier)
                    .renameDeck(deck.id, name);
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete Deck'),
        content: Text(
          'Delete "${deck.name}" and all its cards? This cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              ref.read(deckListProvider.notifier).deleteDeck(deck.id);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;

  const _CountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$count',
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
