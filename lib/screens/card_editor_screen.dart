import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/deck_provider.dart';
import '../models/note_type.dart';

class CardEditorScreen extends ConsumerStatefulWidget {
  final int deckId;
  final int? editNoteId; // null = create new

  const CardEditorScreen({
    super.key,
    required this.deckId,
    this.editNoteId,
  });

  @override
  ConsumerState<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends ConsumerState<CardEditorScreen> {
  NoteType? _selectedNoteType;
  List<TextEditingController> _fieldControllers = [];
  final _tagsController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _fieldControllers) {
      c.dispose();
    }
    _tagsController.dispose();
    super.dispose();
  }

  void _initFieldControllers(NoteType noteType) {
    // Dispose old controllers
    for (final c in _fieldControllers) {
      c.dispose();
    }
    _fieldControllers = noteType.fields
        .map((_) => TextEditingController())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final noteTypesAsync = ref.watch(noteTypeListProvider);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.editNoteId != null ? 'Edit Card' : 'Add Card'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _saving ? null : _save,
          child: _saving
              ? const CupertinoActivityIndicator()
              : const Text('Save'),
        ),
      ),
      child: SafeArea(
        child: noteTypesAsync.when(
          data: (noteTypes) {
            if (_selectedNoteType == null && noteTypes.isNotEmpty) {
              _selectedNoteType = noteTypes.first;
              _initFieldControllers(_selectedNoteType!);
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Note type selector
                const Text(
                  'Note Type',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
                const SizedBox(height: 6),
                CupertinoSlidingSegmentedControl<int>(
                  groupValue: _selectedNoteType != null
                      ? noteTypes.indexOf(_selectedNoteType!)
                      : 0,
                  children: {
                    for (int i = 0; i < noteTypes.length; i++)
                      i: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: Text(
                          noteTypes[i].name,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                  },
                  onValueChanged: (index) {
                    if (index != null) {
                      setState(() {
                        _selectedNoteType = noteTypes[index];
                        _initFieldControllers(_selectedNoteType!);
                      });
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Field inputs
                if (_selectedNoteType != null)
                  ..._buildFieldInputs(_selectedNoteType!),

                const SizedBox(height: 16),

                // Tags
                const Text(
                  'Tags',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
                const SizedBox(height: 6),
                CupertinoTextField(
                  controller: _tagsController,
                  placeholder: 'space-separated tags',
                  padding: const EdgeInsets.all(12),
                ),
              ],
            );
          },
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  List<Widget> _buildFieldInputs(NoteType noteType) {
    final widgets = <Widget>[];
    for (int i = 0; i < noteType.fields.length; i++) {
      widgets.add(Text(
        noteType.fields[i].name,
        style: const TextStyle(
          fontSize: 13,
          color: CupertinoColors.systemGrey,
        ),
      ));
      widgets.add(const SizedBox(height: 6));
      widgets.add(CupertinoTextField(
        controller: _fieldControllers.length > i
            ? _fieldControllers[i]
            : TextEditingController(),
        placeholder: 'Enter ${noteType.fields[i].name}',
        padding: const EdgeInsets.all(12),
        maxLines: 4,
        minLines: 2,
      ));
      widgets.add(const SizedBox(height: 16));
    }
    return widgets;
  }

  Future<void> _save() async {
    if (_selectedNoteType == null) return;

    final fields =
        _fieldControllers.map((c) => c.text).toList();

    // Validate at least the first field is non-empty
    if (fields.isEmpty || fields[0].trim().isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Missing Content'),
          content: const Text('Please fill in at least the first field.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final creator = ref.read(noteCreatorProvider);
      await creator.createNote(
        deckId: widget.deckId,
        noteTypeId: _selectedNoteType!.id,
        fields: fields,
        tags: _tagsController.text.trim(),
      );

      if (!mounted) return;

      // Clear fields for next card
      for (final c in _fieldControllers) {
        c.clear();
      }
      _tagsController.clear();

      // Show brief success feedback
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Card Added'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Add Another'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              child: const Text('Done'),
              onPressed: () {
                Navigator.pop(context); // dismiss dialog
                Navigator.pop(context); // go back
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text('$e'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
