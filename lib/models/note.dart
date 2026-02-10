/// Represents a note which can generate one or more cards.
class Note {
  final int id;
  final String guid;
  final int modelId; // note type id
  final int mod; // modification timestamp
  final String tags;
  final List<String> fields;
  final String sortField;
  final int checksum;
  final String memo; // user's personal study notes

  Note({
    required this.id,
    required this.guid,
    required this.modelId,
    this.mod = 0,
    this.tags = '',
    required this.fields,
    String? sortField,
    this.checksum = 0,
    this.memo = '',
  }) : sortField = sortField ?? (fields.isNotEmpty ? fields[0] : '');

  /// Anki stores fields as unit separator (0x1f) delimited string.
  String get fieldsAsString => fields.join('\x1f');

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'guid': guid,
      'mid': modelId,
      'mod': mod,
      'tags': tags,
      'flds': fieldsAsString,
      'sfld': sortField,
      'csum': checksum,
      'memo': memo,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    final flds = map['flds'] as String? ?? '';
    return Note(
      id: map['id'] as int,
      guid: map['guid'] as String? ?? '',
      modelId: map['mid'] as int,
      mod: map['mod'] as int? ?? 0,
      tags: map['tags'] as String? ?? '',
      fields: flds.split('\x1f'),
      sortField: map['sfld'] as String? ?? '',
      checksum: map['csum'] as int? ?? 0,
      memo: map['memo'] as String? ?? '',
    );
  }

  Note copyWith({
    int? id,
    String? guid,
    int? modelId,
    int? mod,
    String? tags,
    List<String>? fields,
    String? sortField,
    int? checksum,
    String? memo,
  }) {
    return Note(
      id: id ?? this.id,
      guid: guid ?? this.guid,
      modelId: modelId ?? this.modelId,
      mod: mod ?? this.mod,
      tags: tags ?? this.tags,
      fields: fields ?? this.fields,
      sortField: sortField ?? this.sortField,
      checksum: checksum ?? this.checksum,
      memo: memo ?? this.memo,
    );
  }
}
