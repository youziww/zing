/// Card types matching Anki's internal representation.
class CardType {
  static const int newCard = 0;
  static const int learning = 1;
  static const int review = 2;
  static const int relearning = 3;
}

/// Card queue types matching Anki's internal representation.
class CardQueue {
  static const int suspended = -1;
  static const int newQueue = 0;
  static const int learning = 1;
  static const int review = 2;
  static const int relearning = 3;
}

/// Represents a single flashcard in the system.
class ReviewCard {
  final int id;
  final int noteId;
  final int deckId;
  final int ord; // ordinal for multi-card notes
  final int mod; // modification timestamp
  int type; // CardType
  int queue; // CardQueue
  int due; // due date (day number for review, timestamp for learning)
  int interval; // interval in days
  int easeFactor; // ease factor * 1000 (e.g. 2500 = 2.5)
  int reps; // number of reviews
  int lapses; // number of lapses
  int left; // learning steps remaining
  int originalDue;
  int originalDeckId;

  ReviewCard({
    required this.id,
    required this.noteId,
    required this.deckId,
    this.ord = 0,
    this.mod = 0,
    this.type = CardType.newCard,
    this.queue = CardQueue.newQueue,
    this.due = 0,
    this.interval = 0,
    this.easeFactor = 2500,
    this.reps = 0,
    this.lapses = 0,
    this.left = 0,
    this.originalDue = 0,
    this.originalDeckId = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nid': noteId,
      'did': deckId,
      'ord': ord,
      'mod': mod,
      'type': type,
      'queue': queue,
      'due': due,
      'ivl': interval,
      'factor': easeFactor,
      'reps': reps,
      'lapses': lapses,
      'left': left,
      'odue': originalDue,
      'odid': originalDeckId,
    };
  }

  factory ReviewCard.fromMap(Map<String, dynamic> map) {
    return ReviewCard(
      id: map['id'] as int,
      noteId: map['nid'] as int,
      deckId: map['did'] as int,
      ord: map['ord'] as int? ?? 0,
      mod: map['mod'] as int? ?? 0,
      type: map['type'] as int? ?? CardType.newCard,
      queue: map['queue'] as int? ?? CardQueue.newQueue,
      due: map['due'] as int? ?? 0,
      interval: map['ivl'] as int? ?? 0,
      easeFactor: map['factor'] as int? ?? 2500,
      reps: map['reps'] as int? ?? 0,
      lapses: map['lapses'] as int? ?? 0,
      left: map['left'] as int? ?? 0,
      originalDue: map['odue'] as int? ?? 0,
      originalDeckId: map['odid'] as int? ?? 0,
    );
  }

  ReviewCard copyWith({
    int? id,
    int? noteId,
    int? deckId,
    int? ord,
    int? mod,
    int? type,
    int? queue,
    int? due,
    int? interval,
    int? easeFactor,
    int? reps,
    int? lapses,
    int? left,
    int? originalDue,
    int? originalDeckId,
  }) {
    return ReviewCard(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      deckId: deckId ?? this.deckId,
      ord: ord ?? this.ord,
      mod: mod ?? this.mod,
      type: type ?? this.type,
      queue: queue ?? this.queue,
      due: due ?? this.due,
      interval: interval ?? this.interval,
      easeFactor: easeFactor ?? this.easeFactor,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      left: left ?? this.left,
      originalDue: originalDue ?? this.originalDue,
      originalDeckId: originalDeckId ?? this.originalDeckId,
    );
  }
}
