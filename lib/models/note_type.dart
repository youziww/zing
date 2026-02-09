import 'dart:convert';

/// Definition of a field in a note type.
class FieldDef {
  final String name;
  final int ord;
  final bool sticky;

  FieldDef({required this.name, required this.ord, this.sticky = false});

  Map<String, dynamic> toMap() => {'name': name, 'ord': ord, 'sticky': sticky};

  factory FieldDef.fromMap(Map<String, dynamic> map) => FieldDef(
    name: map['name'] as String,
    ord: map['ord'] as int,
    sticky: map['sticky'] as bool? ?? false,
  );
}

/// Template for generating cards from notes.
class CardTemplate {
  final String name;
  final int ord;
  final String frontHtml;
  final String backHtml;

  CardTemplate({
    required this.name,
    required this.ord,
    required this.frontHtml,
    required this.backHtml,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'ord': ord,
    'qfmt': frontHtml,
    'afmt': backHtml,
  };

  factory CardTemplate.fromMap(Map<String, dynamic> map) => CardTemplate(
    name: map['name'] as String,
    ord: map['ord'] as int,
    frontHtml: map['qfmt'] as String? ?? '',
    backHtml: map['afmt'] as String? ?? '',
  );
}

/// Defines a note type (model) with fields and templates.
class NoteType {
  final int id;
  final String name;
  final List<FieldDef> fields;
  final List<CardTemplate> templates;
  final String css;
  final int type; // 0 = standard, 1 = cloze

  NoteType({
    required this.id,
    required this.name,
    required this.fields,
    required this.templates,
    this.css = '',
    this.type = 0,
  });

  bool get isCloze => type == 1;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'flds': jsonEncode(fields.map((f) => f.toMap()).toList()),
      'tmpls': jsonEncode(templates.map((t) => t.toMap()).toList()),
      'css': css,
      'type': type,
    };
  }

  factory NoteType.fromMap(Map<String, dynamic> map) {
    List<FieldDef> fields;
    final fldsRaw = map['flds'];
    if (fldsRaw is String) {
      final list = jsonDecode(fldsRaw) as List;
      fields = list.map((f) => FieldDef.fromMap(f as Map<String, dynamic>)).toList();
    } else if (fldsRaw is List) {
      fields = fldsRaw.map((f) => FieldDef.fromMap(f as Map<String, dynamic>)).toList();
    } else {
      fields = [];
    }

    List<CardTemplate> templates;
    final tmplsRaw = map['tmpls'];
    if (tmplsRaw is String) {
      final list = jsonDecode(tmplsRaw) as List;
      templates = list.map((t) => CardTemplate.fromMap(t as Map<String, dynamic>)).toList();
    } else if (tmplsRaw is List) {
      templates = tmplsRaw.map((t) => CardTemplate.fromMap(t as Map<String, dynamic>)).toList();
    } else {
      templates = [];
    }

    return NoteType(
      id: map['id'] as int,
      name: map['name'] as String? ?? '',
      fields: fields,
      templates: templates,
      css: map['css'] as String? ?? '',
      type: map['type'] as int? ?? 0,
    );
  }

  /// Default "Basic" note type.
  static NoteType basic(int id) => NoteType(
    id: id,
    name: 'Basic',
    fields: [
      FieldDef(name: 'Front', ord: 0),
      FieldDef(name: 'Back', ord: 1),
    ],
    templates: [
      CardTemplate(
        name: 'Card 1',
        ord: 0,
        frontHtml: '{{Front}}',
        backHtml: '{{FrontSide}}<hr id="answer">{{Back}}',
      ),
    ],
    css: '.card { font-family: arial; font-size: 20px; text-align: center; color: black; background-color: white; }',
  );

  /// Default "Basic (and reversed card)" note type.
  static NoteType basicReversed(int id) => NoteType(
    id: id,
    name: 'Basic (and reversed card)',
    fields: [
      FieldDef(name: 'Front', ord: 0),
      FieldDef(name: 'Back', ord: 1),
    ],
    templates: [
      CardTemplate(
        name: 'Card 1',
        ord: 0,
        frontHtml: '{{Front}}',
        backHtml: '{{FrontSide}}<hr id="answer">{{Back}}',
      ),
      CardTemplate(
        name: 'Card 2',
        ord: 1,
        frontHtml: '{{Back}}',
        backHtml: '{{FrontSide}}<hr id="answer">{{Front}}',
      ),
    ],
    css: '.card { font-family: arial; font-size: 20px; text-align: center; color: black; background-color: white; }',
  );

  /// Default "Cloze" note type.
  static NoteType cloze(int id) => NoteType(
    id: id,
    name: 'Cloze',
    fields: [
      FieldDef(name: 'Text', ord: 0),
      FieldDef(name: 'Extra', ord: 1),
    ],
    templates: [
      CardTemplate(
        name: 'Cloze',
        ord: 0,
        frontHtml: '{{cloze:Text}}',
        backHtml: '{{cloze:Text}}<br>{{Extra}}',
      ),
    ],
    css: '.card { font-family: arial; font-size: 20px; text-align: center; color: black; background-color: white; }',
    type: 1,
  );
}
