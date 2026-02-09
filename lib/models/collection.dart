/// Collection metadata.
class Collection {
  final int id;
  final int crt; // creation timestamp (seconds)
  final int mod; // modification timestamp (seconds)

  Collection({
    this.id = 1,
    required this.crt,
    required this.mod,
  });

  /// Day number relative to collection creation.
  int get today {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (now - crt) ~/ 86400;
  }

  /// Timestamp (seconds) for the start of today.
  int get dayStartTimestamp => crt + today * 86400;

  Map<String, dynamic> toMap() {
    return {'id': id, 'crt': crt, 'mod': mod};
  }

  factory Collection.fromMap(Map<String, dynamic> map) {
    return Collection(
      id: map['id'] as int? ?? 1,
      crt: map['crt'] as int,
      mod: map['mod'] as int,
    );
  }
}
