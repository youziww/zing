import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/card_dao.dart';
import '../database/note_dao.dart';
import '../models/note.dart';
import '../providers/deck_provider.dart';
import 'card_editor_screen.dart';

class BrowserScreen extends ConsumerStatefulWidget {
  final int? deckId;

  const BrowserScreen({super.key, this.deckId});

  @override
  ConsumerState<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends ConsumerState<BrowserScreen> {
  final _searchController = TextEditingController();
  final _noteDao = NoteDao();
  final _cardDao = CardDao();
  List<Note> _notes = [];
  late bool _loading = widget.deckId != null;

  @override
  void initState() {
    super.initState();
    // Only auto-load when browsing a specific deck
    if (widget.deckId != null) _loadNotes();
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

  void _clearList() {
    _searchController.clear();
    setState(() {
      _notes = [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Browse'),
        trailing: _notes.isNotEmpty
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _clearList,
                child: const Text('Clear', style: TextStyle(fontSize: 15)),
              )
            : null,
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
            if (!_loading && _notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Showing ${_notes.length} most recent',
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
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
                                onTap: () => _editNote(_notes[index]),
                              ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editNote(Note note) async {
    int deckId;
    if (widget.deckId != null) {
      deckId = widget.deckId!;
    } else {
      final cards = await _cardDao.getByNoteId(note.id);
      if (cards.isEmpty) return;
      deckId = cards.first.deckId;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => CardEditorScreen(
          deckId: deckId,
          editNoteId: note.id,
        ),
      ),
    );
    _loadNotes();
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
      setState(() => _notes.removeWhere((n) => n.id == note.id));
      ref.invalidate(deckListProvider);
    }
  }
}

class _NoteTile extends StatelessWidget {
  final Note note;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _NoteTile({required this.note, required this.onDelete, required this.onTap});

  /// Strip HTML tags, sound refs, ruby syntax, entities, control chars.
  static String _cleanText(String text) {
    var s = text
        .replaceAll(RegExp(r'\[sound:[^\]]*\]'), '') // remove [sound:...]
        .replaceAll(RegExp(r'<[^>]*>'), '')          // strip HTML tags
        .replaceAll(RegExp(r'\w+\[([^\]]+)\]'), r'\1') // ruby 丸[まる] → まる
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'[\x00-\x1f]'), '')      // remove control chars
        .replaceAll(RegExp(r'\s+'), ' ')              // collapse whitespace
        .trim();
    return s.isEmpty ? '(empty)' : s;
  }

  /// Pick the best display text for front/back of a note.
  static String _frontText(Note note) {
    // sortField is always clean (the word itself)
    if (note.sortField.isNotEmpty) return _cleanText(note.sortField);
    return _cleanText(note.fields.isNotEmpty ? note.fields[0] : '');
  }

  static final _uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false);

  static String _backText(Note note) {
    final front = _cleanText(note.sortField);
    // Find the first meaningful field: ≥3 chars, not UUID, not same as front
    for (final f in note.fields) {
      final cleaned = _cleanText(f);
      if (cleaned == '(empty)' || cleaned == front) continue;
      if (_uuidPattern.hasMatch(cleaned)) continue;
      if (cleaned.length >= 3) return cleaned;
    }
    // Fallback: first non-empty, non-front field
    for (final f in note.fields) {
      final cleaned = _cleanText(f);
      if (cleaned != '(empty)' && cleaned != front && !_uuidPattern.hasMatch(cleaned)) {
        return cleaned;
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final front = _frontText(note);
    final back = _backText(note);

    return CupertinoListTile(
      onTap: onTap,
      title: Text(
        front,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: back.isNotEmpty && back != '(empty)'
          ? Text(
              back,
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
