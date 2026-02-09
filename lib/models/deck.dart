import 'dart:convert';

/// Represents a deck (collection of cards).
class Deck {
  final int id;
  final String name;
  final String description;
  final int mod;
  final Map<String, dynamic> config;

  // Transient counts (not stored in DB)
  int newCount;
  int learnCount;
  int reviewCount;

  Deck({
    required this.id,
    required this.name,
    this.description = '',
    this.mod = 0,
    Map<String, dynamic>? config,
    this.newCount = 0,
    this.learnCount = 0,
    this.reviewCount = 0,
  }) : config = config ?? {};

  /// Get the parent deck name (before "::").
  String? get parentName {
    final idx = name.lastIndexOf('::');
    return idx >= 0 ? name.substring(0, idx) : null;
  }

  /// Get the short name (after last "::").
  String get shortName {
    final idx = name.lastIndexOf('::');
    return idx >= 0 ? name.substring(idx + 2) : name;
  }

  /// Nesting depth (0 for top-level).
  int get depth => '::'.allMatches(name).length;

  int get totalDueCount => newCount + learnCount + reviewCount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'mod': mod,
      'config': jsonEncode(config),
    };
  }

  factory Deck.fromMap(Map<String, dynamic> map) {
    final configRaw = map['config'];
    Map<String, dynamic> config;
    if (configRaw is String) {
      config = jsonDecode(configRaw) as Map<String, dynamic>;
    } else if (configRaw is Map) {
      config = Map<String, dynamic>.from(configRaw);
    } else {
      config = {};
    }
    return Deck(
      id: map['id'] as int,
      name: map['name'] as String? ?? 'Default',
      description: map['description'] as String? ?? '',
      mod: map['mod'] as int? ?? 0,
      config: config,
    );
  }

  Deck copyWith({
    int? id,
    String? name,
    String? description,
    int? mod,
    Map<String, dynamic>? config,
  }) {
    return Deck(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      mod: mod ?? this.mod,
      config: config ?? this.config,
    );
  }
}
