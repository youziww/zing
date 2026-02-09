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
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Zing'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.chart_bar),
              onPressed: () => Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const StatsScreen()),
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.search),
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
            // Today's stats bar
            todayStats.when(
              data: (stats) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: CupertinoColors.systemGroupedBackground,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatChip(
                      label: 'Studied',
                      value: '${stats.reviewCount}',
                      color: CupertinoColors.systemBlue,
                    ),
                    _StatChip(
                      label: 'Accuracy',
                      value: stats.reviewCount > 0
                          ? '${(stats.accuracy * 100).toStringAsFixed(0)}%'
                          : '-',
                      color: CupertinoColors.systemGreen,
                    ),
                  ],
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            // Deck list
            Expanded(
              child: decksAsync.when(
                data: (decks) => decks.isEmpty
                    ? const Center(
                        child: Text(
                          'No decks yet.\nTap + to create one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: CupertinoColors.systemGrey,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: decks.length,
                        itemBuilder: (context, index) =>
                            _DeckTile(deck: decks[index]),
                      ),
                loading: () =>
                    const Center(child: CupertinoActivityIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
            // Bottom action bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: CupertinoColors.separator,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.add, size: 18),
                          SizedBox(width: 6),
                          Text('Add Deck'),
                        ],
                      ),
                      onPressed: () => _showAddDeckDialog(context, ref),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    color: CupertinoColors.systemOrange,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.arrow_down_doc,
                            size: 18, color: CupertinoColors.white),
                        SizedBox(width: 6),
                        Text('Import',
                            style: TextStyle(color: CupertinoColors.white)),
                      ],
                    ),
                    onPressed: () => _importApkg(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

class _DeckTile extends ConsumerWidget {
  final Deck deck;

  const _DeckTile({required this.deck});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onLongPress: () => _showContextMenu(context, ref),
      child: CupertinoListTile(
        padding: EdgeInsets.only(
          left: 16.0 + deck.depth * 20.0,
          right: 16.0,
          top: 12,
          bottom: 12,
        ),
        title: Text(
          deck.shortName,
          style: const TextStyle(fontSize: 17),
        ),
        subtitle: Row(
          children: [
            _CountBadge(
              count: deck.newCount,
              color: CupertinoColors.systemBlue,
            ),
            const SizedBox(width: 8),
            _CountBadge(
              count: deck.learnCount,
              color: CupertinoColors.systemRed,
            ),
            const SizedBox(width: 8),
            _CountBadge(
              count: deck.reviewCount,
              color: CupertinoColors.systemGreen,
            ),
          ],
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.add_circled,
              color: CupertinoColors.systemBlue),
          onPressed: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (_) => CardEditorScreen(deckId: deck.id),
              ),
            ).then((_) => ref.read(deckListProvider.notifier).refresh());
          },
        ),
        onTap: () {
          if (deck.totalDueCount > 0) {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (_) => StudyScreen(deckId: deck.id, deckName: deck.name),
              ),
            ).then((_) => ref.read(deckListProvider.notifier).refresh());
          }
        },
      ),
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
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: CupertinoColors.systemGrey,
          ),
        ),
      ],
    );
  }
}
