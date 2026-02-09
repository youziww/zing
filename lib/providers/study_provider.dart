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

  /// Build field lookup map: name -> value
  Map<String, String> get _fieldMap {
    final map = <String, String>{};
    for (int i = 0; i < noteType.fields.length && i < note.fields.length; i++) {
      map[noteType.fields[i].name] = note.fields[i];
    }
    return map;
  }

  /// Check if this note type has many fields (complex template).
  bool get _isComplex => noteType.fields.length > 10;

  /// Render front HTML.
  String get frontHtml {
    if (_isComplex) return _wrapWithCss(_simpleFront());
    if (card.ord < noteType.templates.length) {
      var html = noteType.templates[card.ord].frontHtml;
      html = _render(html);
      if (noteType.isCloze) {
        html = _processCloze(html, card.ord + 1, showAnswer: false);
      }
      return _wrapWithCss(html);
    }
    return _wrapWithCss(note.fields.isNotEmpty ? note.fields[0] : '');
  }

  /// Render back HTML.
  String get backHtml {
    if (_isComplex) return _wrapWithCss(_simpleBack());
    if (card.ord < noteType.templates.length) {
      var html = noteType.templates[card.ord].backHtml;
      html = html.replaceAll('{{FrontSide}}', _renderRaw(noteType.templates[card.ord].frontHtml));
      html = _render(html);
      if (noteType.isCloze) {
        html = _processCloze(html, card.ord + 1, showAnswer: true);
      }
      return _wrapWithCss(html);
    }
    return _wrapWithCss(note.fields.length > 1 ? note.fields[1] : '');
  }

  String get frontHtmlRaw {
    if (_isComplex) return _simpleFront();
    if (card.ord < noteType.templates.length) {
      return _renderRaw(noteType.templates[card.ord].frontHtml);
    }
    return note.fields.isNotEmpty ? note.fields[0] : '';
  }

  /// Simplified front for complex note types (e.g., JLPT vocabulary).
  String _simpleFront() {
    final m = _fieldMap;
    // Try common vocabulary field names
    final kanji = m['VocabKanji'] ?? m['Front'] ?? m['Word'] ?? m['Expression']
        ?? (note.fields.isNotEmpty ? note.fields[0] : '');
    return '''
<div style="text-align:center; padding:20px;">
  <h1 style="font-size:48px; margin:20px 0; font-weight:normal;" lang="ja">$kanji</h1>
</div>
''';
  }

  /// Simplified back for complex note types.
  String _simpleBack() {
    final m = _fieldMap;
    final kanji = m['VocabKanji'] ?? m['Front'] ?? (note.fields.isNotEmpty ? note.fields[0] : '');
    final furigana = _clean(m['VocabFurigana'] ?? m['Reading'] ?? '');
    final pitch = m['VocabPitch'] ?? '';
    final pos = m['VocabPoS'] ?? '';
    final defSC = _clean(m['VocabDefSC'] ?? m['VocabDef'] ?? m['Back'] ?? m['Meaning']
        ?? (note.fields.length > 1 ? note.fields[1] : ''));
    final plus = _clean(m['VocabPlus'] ?? '');

    // Find first non-empty example sentence
    String sentKanji = '', sentDef = '';
    for (int i = 1; i <= 4; i++) {
      final sk = m['SentKanji$i'] ?? '';
      if (sk.isNotEmpty) {
        sentKanji = _clean(sk);
        sentDef = _clean(m['SentDefSC$i'] ?? m['SentDefTC$i'] ?? '');
        break;
      }
    }

    final buf = StringBuffer();
    buf.write('<div style="text-align:center; padding:16px; font-size:16px; line-height:1.8;">');
    buf.write('<h1 style="font-size:42px; margin:10px 0; font-weight:normal;" lang="ja">$kanji</h1>');
    if (furigana.isNotEmpty) {
      buf.write('<div style="font-size:22px; color:#666;" lang="ja">$furigana');
      if (pitch.isNotEmpty) buf.write(' <span style="color:#999; font-size:16px;">$pitch</span>');
      if (pos.isNotEmpty) buf.write(' <span style="color:#999; font-size:14px;">[$pos]</span>');
      buf.write('</div>');
    }
    buf.write('<div style="font-size:20px; margin:16px 0; color:#333;">$defSC</div>');
    if (plus.isNotEmpty) {
      buf.write('<div style="font-size:14px; color:#888; margin:8px 0;">$plus</div>');
    }
    if (sentKanji.isNotEmpty) {
      buf.write('<hr style="border:none; border-top:1px solid #ddd; margin:16px 0;">');
      buf.write('<div style="font-size:18px; text-align:left;" lang="ja">$sentKanji</div>');
      if (sentDef.isNotEmpty) {
        buf.write('<div style="font-size:16px; text-align:left; color:#666; margin-top:6px;">$sentDef</div>');
      }
    }
    buf.write('</div>');
    return buf.toString();
  }

  /// Clean field value: remove [sound:...], strip readings for display.
  String _clean(String text) {
    text = text.replaceAll(RegExp(r'\[sound:[^\]]*\]'), '');
    return text.trim();
  }

  /// Full template rendering for simple note types.
  String _render(String html) {
    html = _renderRaw(html);
    return html;
  }

  String _renderRaw(String html) {
    final fields = _fieldMap;
    final tags = note.tags.trim();

    // Process conditionals: {{#Field}}...{{/Field}} and {{^Field}}...{{/Field}}
    // Run multiple passes to handle nesting
    for (int pass = 0; pass < 3; pass++) {
      html = html.replaceAllMapped(
        RegExp(r'\{\{([#^])(\w+)\}\}(.*?)\{\{/\2\}\}', dotAll: true),
        (m) {
          final isPositive = m.group(1) == '#';
          final name = m.group(2)!;
          final content = m.group(3)!;
          final value = name == 'Tags' ? tags : (fields[name] ?? '');
          final isEmpty = value.trim().isEmpty;
          if (isPositive) return isEmpty ? '' : content;
          return isEmpty ? content : '';
        },
      );
    }

    // Substitute Tags
    html = html.replaceAll('{{Tags}}', tags);

    // Substitute field values with all filter variants
    for (final entry in fields.entries) {
      html = html.replaceAll('{{${entry.key}}}', entry.value);
      html = html.replaceAll('{{kana:${entry.key}}}', _stripReadings(entry.value));
      html = html.replaceAll('{{text:${entry.key}}}', _stripHtml(entry.value));
      html = html.replaceAll('{{furigana:${entry.key}}}', entry.value);
      html = html.replaceAll('{{cloze:${entry.key}}}', entry.value);
    }

    // Remove [sound:...] and remaining {{...}} tags
    html = html.replaceAll(RegExp(r'\[sound:[^\]]*\]'), '');
    html = html.replaceAll(RegExp(r'\{\{[^}]*\}\}'), '');

    return html;
  }

  String _stripReadings(String text) {
    return text.replaceAllMapped(
      RegExp(r'(\S+)\[(\S+)\]'),
      (m) => m.group(2)!,
    );
  }

  String _stripHtml(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  String _processCloze(String html, int clozeNum, {required bool showAnswer}) {
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
      return answer;
    });
  }

  String _wrapWithCss(String html) {
    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
body { font-family: -apple-system, 'Hiragino Sans', 'PingFang SC', sans-serif; margin: 0; padding: 8px; }
.cloze { font-weight: bold; color: #00f; }
</style>
</head>
<body>
$html
</body>
</html>
''';
  }
}
