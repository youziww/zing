import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../providers/study_provider.dart';
import '../scheduler/card_state.dart';
import 'card_editor_screen.dart';

class StudyScreen extends ConsumerStatefulWidget {
  final int deckId;
  final String deckName;

  const StudyScreen({
    super.key,
    required this.deckId,
    required this.deckName,
  });

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  CardContent? _cardContent;
  bool _loadingContent = false;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() => _loadingContent = true);
    try {
      final notifier = ref.read(studySessionProvider(widget.deckId).notifier);
      final content = await notifier.getCardContent();
      if (mounted) {
        setState(() {
          _cardContent = content;
          _loadingContent = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingContent = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(studySessionProvider(widget.deckId));

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          widget.deckName.contains('::')
              ? widget.deckName.split('::').last
              : widget.deckName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _buildNavTrailing(sessionAsync.valueOrNull),
      ),
      child: SafeArea(
        child: sessionAsync.when(
          data: (session) {
            if (session.isFinished) return _buildCongratsView(session);
            return _buildStudyView(session);
          },
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget? _buildNavTrailing(StudySessionState? session) {
    if (session == null) return null;
    final showEdit = session.isShowingAnswer && _cardContent != null;
    final showUndo = session.canUndo;
    if (!showEdit && !showUndo) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showUndo)
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _undo,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.arrow_uturn_left, size: 18),
                SizedBox(width: 3),
                Text('撤销', style: TextStyle(fontSize: 15)),
              ],
            ),
          ),
        if (showEdit)
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _editCurrentCard,
            child: const Icon(CupertinoIcons.pencil, size: 22),
          ),
      ],
    );
  }

  Widget _buildCongratsView(StudySessionState session) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.checkmark_circle_fill,
              size: 64,
              color: CupertinoColors.systemGreen,
            ),
            const SizedBox(height: 20),
            const Text(
              'Congratulations!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'You have finished all cards for now.',
              style: TextStyle(fontSize: 16, color: CupertinoColors.systemGrey),
            ),
            const SizedBox(height: 32),
            CupertinoButton(
              child: const Text('Back to Decks'),
              onPressed: () => Navigator.pop(context),
            ),
            if (session.canUndo) ...[
              const SizedBox(height: 8),
              CupertinoButton(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.arrow_uturn_left, size: 18),
                    SizedBox(width: 6),
                    Text('Undo'),
                  ],
                ),
                onPressed: () => _undo(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStudyView(StudySessionState session) {
    if (_cardContent?.card.id != session.currentCard?.id && !_loadingContent) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadContent());
    }

    return Column(
      children: [
        _buildProgressBar(session),
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (!session.isShowingAnswer) {
                ref
                    .read(studySessionProvider(widget.deckId).notifier)
                    .showAnswer();
              }
            },
            child: _buildCardContent(session),
          ),
        ),
        if (session.isShowingAnswer) _buildAnswerButtons(session),
        if (!session.isShowingAnswer) _buildShowAnswerButton(),
      ],
    );
  }

  Widget _buildProgressBar(StudySessionState session) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: CupertinoColors.separator, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CountLabel(count: session.counts['new'] ?? 0, color: CupertinoColors.systemBlue),
          const SizedBox(width: 24),
          _CountLabel(count: session.counts['learn'] ?? 0, color: CupertinoColors.systemRed),
          const SizedBox(width: 24),
          _CountLabel(count: session.counts['review'] ?? 0, color: CupertinoColors.systemGreen),
        ],
      ),
    );
  }

  Widget _buildCardContent(StudySessionState session) {
    if (_loadingContent || _cardContent == null) {
      return const Center(child: CupertinoActivityIndicator());
    }

    final html = session.isShowingAnswer
        ? _cardContent!.backHtml
        : _cardContent!.frontHtml;
    final memo = _cardContent!.note.memo;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HtmlWidget(
                html,
                textStyle: const TextStyle(fontSize: 18),
              ),
              if (session.isShowingAnswer) ...[
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _editCurrentCard,
                  child: Text(
                    memo.isNotEmpty ? memo : 'Tap to add notes...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: memo.isNotEmpty
                          ? CupertinoColors.systemGrey
                          : CupertinoColors.systemGrey3,
                      fontStyle: memo.isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShowAnswerButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: const Text('Show Answer', style: TextStyle(fontSize: 17)),
          onPressed: () {
            ref.read(studySessionProvider(widget.deckId).notifier).showAnswer();
          },
        ),
      ),
    );
  }

  Widget _buildAnswerButtons(StudySessionState session) {
    final times = session.nextReviewTimes;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: CupertinoColors.separator, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          _AnswerButton(
            label: 'Again', subtitle: times[Ease.again] ?? '',
            color: CupertinoColors.systemRed, onPressed: () => _answer(Ease.again),
          ),
          _AnswerButton(
            label: 'Hard', subtitle: times[Ease.hard] ?? '',
            color: CupertinoColors.systemOrange, onPressed: () => _answer(Ease.hard),
          ),
          _AnswerButton(
            label: 'Good', subtitle: times[Ease.good] ?? '',
            color: CupertinoColors.systemGreen, onPressed: () => _answer(Ease.good),
          ),
          _AnswerButton(
            label: 'Easy', subtitle: times[Ease.easy] ?? '',
            color: CupertinoColors.systemBlue, onPressed: () => _answer(Ease.easy),
          ),
        ],
      ),
    );
  }

  Future<void> _editCurrentCard() async {
    if (_cardContent == null) return;
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => CardEditorScreen(
          deckId: widget.deckId,
          editNoteId: _cardContent!.note.id,
        ),
      ),
    );
    // Reload content after edit
    _loadContent();
  }

  Future<void> _undo() async {
    await ref.read(studySessionProvider(widget.deckId).notifier).undoLastAnswer();
    _loadContent();
  }

  Future<void> _answer(int ease) async {
    await ref.read(studySessionProvider(widget.deckId).notifier).answerCard(ease);
    _loadContent();
  }
}

class _CountLabel extends StatelessWidget {
  final int count;
  final Color color;

  const _CountLabel({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$count',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onPressed;

  const _AnswerButton({
    required this.label, required this.subtitle,
    required this.color, required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: color,
          borderRadius: BorderRadius.circular(10),
          onPressed: onPressed,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w600, fontSize: 14)),
              if (subtitle.isNotEmpty)
                Text(subtitle, style: const TextStyle(color: CupertinoColors.white, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
