import 'package:flutter_test/flutter_test.dart';
import 'package:zing/models/card.dart';
import 'package:zing/models/note.dart';
import 'package:zing/models/deck.dart';
import 'package:zing/models/note_type.dart';
import 'package:zing/models/review_log.dart';
import 'package:zing/models/collection.dart';

void main() {
  group('Card Model', () {
    test('toMap/fromMap round-trip', () {
      final card = ReviewCard(
        id: 1,
        noteId: 10,
        deckId: 1,
        ord: 0,
        type: CardType.review,
        queue: CardQueue.review,
        due: 100,
        interval: 10,
        easeFactor: 2500,
        reps: 5,
        lapses: 1,
      );

      final map = card.toMap();
      final restored = ReviewCard.fromMap(map);

      expect(restored.id, 1);
      expect(restored.noteId, 10);
      expect(restored.type, CardType.review);
      expect(restored.queue, CardQueue.review);
      expect(restored.interval, 10);
      expect(restored.easeFactor, 2500);
      expect(restored.reps, 5);
      expect(restored.lapses, 1);
    });

    test('copyWith creates proper copy', () {
      final card = ReviewCard(id: 1, noteId: 1, deckId: 1);
      final copy = card.copyWith(interval: 5, easeFactor: 2700);

      expect(copy.id, 1);
      expect(copy.interval, 5);
      expect(copy.easeFactor, 2700);
      expect(card.interval, 0); // original unchanged
    });
  });

  group('Note Model', () {
    test('toMap/fromMap round-trip', () {
      final note = Note(
        id: 1,
        guid: 'abc123',
        modelId: 1,
        fields: ['Front text', 'Back text'],
        tags: 'tag1 tag2',
      );

      final map = note.toMap();
      final restored = Note.fromMap(map);

      expect(restored.id, 1);
      expect(restored.guid, 'abc123');
      expect(restored.fields.length, 2);
      expect(restored.fields[0], 'Front text');
      expect(restored.fields[1], 'Back text');
      expect(restored.sortField, 'Front text');
    });

    test('fields stored as unit separator delimited', () {
      final note = Note(
        id: 1,
        guid: 'x',
        modelId: 1,
        fields: ['Hello', 'World'],
      );
      expect(note.fieldsAsString, 'Hello\x1fWorld');
    });
  });

  group('Deck Model', () {
    test('toMap/fromMap round-trip', () {
      final deck = Deck(
        id: 1,
        name: 'Parent::Child',
        description: 'A test deck',
      );

      final map = deck.toMap();
      final restored = Deck.fromMap(map);

      expect(restored.id, 1);
      expect(restored.name, 'Parent::Child');
    });

    test('hierarchical name parsing', () {
      final deck = Deck(id: 1, name: 'Languages::Japanese::Vocab');
      expect(deck.shortName, 'Vocab');
      expect(deck.parentName, 'Languages::Japanese');
      expect(deck.depth, 2);
    });

    test('top-level deck has no parent', () {
      final deck = Deck(id: 1, name: 'Default');
      expect(deck.parentName, null);
      expect(deck.shortName, 'Default');
      expect(deck.depth, 0);
    });

    test('totalDueCount', () {
      final deck = Deck(id: 1, name: 'Test');
      deck.newCount = 5;
      deck.learnCount = 3;
      deck.reviewCount = 10;
      expect(deck.totalDueCount, 18);
    });
  });

  group('NoteType Model', () {
    test('Basic note type has correct structure', () {
      final basic = NoteType.basic(1);
      expect(basic.name, 'Basic');
      expect(basic.fields.length, 2);
      expect(basic.fields[0].name, 'Front');
      expect(basic.fields[1].name, 'Back');
      expect(basic.templates.length, 1);
      expect(basic.isCloze, false);
    });

    test('Basic (and reversed) has 2 templates', () {
      final reversed = NoteType.basicReversed(1);
      expect(reversed.templates.length, 2);
    });

    test('Cloze note type is marked as cloze', () {
      final cloze = NoteType.cloze(1);
      expect(cloze.isCloze, true);
      expect(cloze.type, 1);
      expect(cloze.fields[0].name, 'Text');
      expect(cloze.fields[1].name, 'Extra');
    });

    test('toMap/fromMap round-trip', () {
      final original = NoteType.basic(12345);
      final map = original.toMap();
      final restored = NoteType.fromMap(map);

      expect(restored.id, 12345);
      expect(restored.name, 'Basic');
      expect(restored.fields.length, 2);
      expect(restored.templates.length, 1);
    });
  });

  group('ReviewLog Model', () {
    test('toMap/fromMap round-trip', () {
      final log = ReviewLog(
        id: 1000,
        cardId: 1,
        ease: 3,
        interval: 10,
        lastInterval: 5,
        factor: 2500,
        time: 3000,
        type: 1,
      );

      final map = log.toMap();
      final restored = ReviewLog.fromMap(map);

      expect(restored.id, 1000);
      expect(restored.cardId, 1);
      expect(restored.ease, 3);
      expect(restored.interval, 10);
      expect(restored.type, 1);
    });
  });

  group('Collection Model', () {
    test('today calculates correct day number', () {
      final now = DateTime.now();
      final crt = DateTime(now.year, now.month, now.day, 4)
              .millisecondsSinceEpoch ~/
          1000;
      final col = Collection(crt: crt, mod: crt);

      // Today should be 0 (if current time is after 4am)
      // or might be -1 if before 4am - depends on when test runs
      expect(col.today, greaterThanOrEqualTo(0));
    });
  });
}
