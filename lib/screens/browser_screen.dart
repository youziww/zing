import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/note_dao.dart';
import '../models/note.dart';
import '../providers/deck_provider.dart';

class BrowserScreen extends ConsumerStatefulWidget {
  final int? deckId;

  const BrowserScreen({super.key, this.deckId});

  @override
  ConsumerState<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends ConsumerState<BrowserScreen> {
  final _searchController = TextEditingController();
  final _noteDao = NoteDao();
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() => _loading = true);
    try {
      if (widget.deckId != null) {
        _notes = await _noteDao.getByDeckId(widget.deckId!);
      } else {
        _notes = await _noteDao.getAll();
      }
    } catch (_) {
      _notes = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      _loadNotes();
      return;
    }
    setState(() => _loading = true);
    _notes = await _noteDao.search(query);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Browse'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: CupertinoSearchTextField(
                controller: _searchController,
                onChanged: _search,
                placeholder: 'Search cards...',
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _notes.isEmpty
                      ? const Center(
                          child: Text(
                            'No cards found.',
                            style: TextStyle(
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _notes.length,
                          itemBuilder: (context, index) =>
                              _NoteTile(
                                note: _notes[index],
                                onDelete: () => _deleteNote(_notes[index]),
                              ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteNote(Note note) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete Note'),
        content: Text(
          'Delete "${note.sortField}" and all its cards?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final creator = ref.read(noteCreatorProvider);
      await creator.deleteNote(note.id);
      _loadNotes();
      ref.invalidate(deckListProvider);
    }
  }
}

class _NoteTile extends StatelessWidget {
  final Note note;
  final VoidCallback onDelete;

  const _NoteTile({required this.note, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final preview = note.fields.isNotEmpty ? note.fields[0] : '(empty)';
    // Strip HTML tags for display
    final cleanPreview = preview.replaceAll(RegExp(r'<[^>]*>'), '');

    return CupertinoListTile(
      title: Text(
        cleanPreview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: note.fields.length > 1
          ? Text(
              note.fields[1].replaceAll(RegExp(r'<[^>]*>'), ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: CupertinoColors.systemGrey),
            )
          : null,
      additionalInfo: note.tags.isNotEmpty
          ? Text(
              note.tags,
              style: const TextStyle(
                fontSize: 11,
                color: CupertinoColors.systemGrey2,
              ),
            )
          : null,
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onDelete,
        child: const Icon(
          CupertinoIcons.delete,
          color: CupertinoColors.destructiveRed,
          size: 20,
        ),
      ),
    );
  }
}
