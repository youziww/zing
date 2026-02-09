import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/card.dart';
import '../models/note.dart';
import '../models/note_type.dart';
import '../database/note_dao.dart';
import '../database/note_type_dao.dart';
import '../database/database_helper.dart';
import '../services/study_service.dart';
import '../scheduler/deck_options.dart';
import 'deck_provider.dart';

/// State for a study session.
class StudySessionState {
  final int deckId;
  final List<ReviewCard> queue;
  final int currentIndex;
  final bool isShowingAnswer;
  final Map<int, String> nextReviewTimes;
  final bool isFinished;
  final Map<String, int> counts; // new, learn, review

  StudySessionState({
    required this.deckId,
    this.queue = const [],
    this.currentIndex = 0,
    this.isShowingAnswer = false,
    this.nextReviewTimes = const {},
    this.isFinished = false,
    this.counts = const {'new': 0, 'learn': 0, 'review': 0},
  });

  ReviewCard? get currentCard =>
      queue.isNotEmpty && currentIndex < queue.length
          ? queue[currentIndex]
          : null;

  int get remainingCount => queue.length - currentIndex;

  StudySessionState copyWith({
    int? deckId,
    List<ReviewCard>? queue,
    int? currentIndex,
    bool? isShowingAnswer,
    Map<int, String>? nextReviewTimes,
    bool? isFinished,
    Map<String, int>? counts,
  }) {
    return StudySessionState(
      deckId: deckId ?? this.deckId,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isShowingAnswer: isShowingAnswer ?? this.isShowingAnswer,
      nextReviewTimes: nextReviewTimes ?? this.nextReviewTimes,
      isFinished: isFinished ?? this.isFinished,
      counts: counts ?? this.counts,
    );
  }
}

/// Provider family for study sessions keyed by deck ID.
final studySessionProvider = AsyncNotifierProviderFamily<
    StudySessionNotifier, StudySessionState, int>(StudySessionNotifier.new);

class StudySessionNotifier
    extends FamilyAsyncNotifier<StudySessionState, int> {
  final _studyService = StudyService();
  final _noteDao = NoteDao();
  final _noteTypeDao = NoteTypeDao();
  final _dbHelper = DatabaseHelper.instance;
  late DeckOptions _options;

  @override
  Future<StudySessionState> build(int arg) async {
    _options = await ref.read(deckListProvider.notifier).getDeckOptions(arg);
    return _loadSession(arg);
  }

  Future<StudySessionState> _loadSession(int deckId) async {
    final queue = await _studyService.getStudyQueue(deckId, _options);
    final counts = await _studyService.getCardCounts(deckId);

    if (queue.isEmpty) {
      return StudySessionState(
        deckId: deckId,
        isFinished: true,
        counts: counts,
      );
    }

    final times = await _getReviewTimes(queue[0]);

    return StudySessionState(
      deckId: deckId,
      queue: queue,
      currentIndex: 0,
      nextReviewTimes: times,
      counts: counts,
    );
  }

  Future<Map<int, String>> _getReviewTimes(ReviewCard card) async {
    final col = await _dbHelper.getCollection();
    return _studyService.getNextReviewTimes(
        card, _options, col.today, col.dayStartTimestamp);
  }

  void showAnswer() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(isShowingAnswer: true));
  }

  Future<void> answerCard(int ease) async {
    final current = state.valueOrNull;
    if (current == null || current.currentCard == null) return;

    await _studyService.answerCard(current.currentCard!, ease, _options);

    // Reload the study queue
    final newState = await _loadSession(current.deckId);
    state = AsyncValue.data(newState);

    // Refresh deck list counts
    ref.invalidate(deckListProvider);
  }

  /// Get note content for the current card.
  Future<CardContent?> getCardContent() async {
    final current = state.valueOrNull;
    if (current?.currentCard == null) return null;

    final card = current!.currentCard!;
    final note = await _noteDao.getById(card.noteId);
    if (note == null) return null;

    final noteType = await _noteTypeDao.getById(note.modelId);
    if (noteType == null) return null;

    return CardContent(
      note: note,
      noteType: noteType,
      card: card,
    );
  }
}

/// Resolved card content for display.
class CardContent {
  final Note note;
  final NoteType noteType;
  final ReviewCard card;

  CardContent({
    required this.note,
    required this.noteType,
    required this.card,
  });

  /// Render front HTML with field substitution.
  String get frontHtml {
    if (card.ord < noteType.templates.length) {
      var html = noteType.templates[card.ord].frontHtml;
      html = _substituteFields(html);
      if (noteType.isCloze) {
        html = _processCloze(html, card.ord + 1, showAnswer: false);
      }
      return _wrapWithCss(html);
    }
    return _wrapWithCss(note.fields.isNotEmpty ? note.fields[0] : '');
  }

  /// Render back HTML with field substitution.
  String get backHtml {
    if (card.ord < noteType.templates.length) {
      var html = noteType.templates[card.ord].backHtml;
      // Replace {{FrontSide}} with front content
      html = html.replaceAll('{{FrontSide}}', frontHtmlRaw);
      html = _substituteFields(html);
      if (noteType.isCloze) {
        html = _processCloze(html, card.ord + 1, showAnswer: true);
      }
      return _wrapWithCss(html);
    }
    return _wrapWithCss(note.fields.length > 1 ? note.fields[1] : '');
  }

  String get frontHtmlRaw {
    if (card.ord < noteType.templates.length) {
      var html = noteType.templates[card.ord].frontHtml;
      html = _substituteFields(html);
      if (noteType.isCloze) {
        html = _processCloze(html, card.ord + 1, showAnswer: false);
      }
      return html;
    }
    return note.fields.isNotEmpty ? note.fields[0] : '';
  }

  String _substituteFields(String html) {
    for (int i = 0; i < noteType.fields.length && i < note.fields.length; i++) {
      html = html.replaceAll('{{${noteType.fields[i].name}}', note.fields[i]);
      // Also handle cloze field references
      html = html.replaceAll('{{cloze:${noteType.fields[i].name}}}', note.fields[i]);
    }
    return html;
  }

  String _processCloze(String html, int clozeNum, {required bool showAnswer}) {
    // Replace {{c<N>::text}} or {{c<N>::text::hint}}
    final pattern = RegExp(r'\{\{c(\d+)::(.*?)(?:::(.*?))?\}\}');
    return html.replaceAllMapped(pattern, (match) {
      final num = int.parse(match.group(1)!);
      final answer = match.group(2)!;
      final hint = match.group(3);

      if (num == clozeNum) {
        if (showAnswer) {
          return '<span class="cloze">$answer</span>';
        } else {
          return '<span class="cloze">[${hint ?? '...'}]</span>';
        }
      }
      return answer; // Show other clozes as plain text
    });
  }

  String _wrapWithCss(String html) {
    return '''
<!DOCTYPE html>
<html>
<head>
<style>
${noteType.css}
.cloze { font-weight: bold; color: #00f; }
</style>
</head>
<body class="card">
$html
</body>
</html>
''';
  }
}
