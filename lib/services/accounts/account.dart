class Account {
  Account({
    required this.id,
    required this.type,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.baseUrl,
    this.dbName,
    this.isPrimary = false,
  });

  final String id;
  final AccountType type;
  final String name;

  // Remote service base URL (for Miniflux/Fever), e.g. https://rss.example.com
  final String? baseUrl;

  // For per-account DB isolation. Primary account uses legacy-safe resolver and
  // may leave this null.
  final String? dbName;

  // Primary means "open existing DB with PathManager.getIsarLocation()" to
  // avoid silent data loss during migration.
  final bool isPrimary;

  final DateTime createdAt;
  final DateTime updatedAt;

  Account copyWith({
    String? id,
    AccountType? type,
    String? name,
    String? baseUrl,
    String? dbName,
    bool? isPrimary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      dbName: dbName ?? this.dbName,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static Account fromJson(Map<String, Object?> json) {
    return Account(
      id: json['id'] as String,
      type: AccountTypeX.fromWire(json['type'] as String),
      name: json['name'] as String,
      baseUrl: json['baseUrl'] as String?,
      dbName: json['dbName'] as String?,
      isPrimary: (json['isPrimary'] as bool?) ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'type': type.wire,
      'name': name,
      'baseUrl': baseUrl,
      'dbName': dbName,
      'isPrimary': isPrimary,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

enum AccountType { local, miniflux, fever, googleReader }

extension AccountTypeX on AccountType {
  String get wire => switch (this) {
    AccountType.local => 'local',
    AccountType.miniflux => 'miniflux',
    AccountType.fever => 'fever',
    AccountType.googleReader => 'googleReader',
  };

  static AccountType fromWire(String wire) {
    switch (wire) {
      case 'local':
        return AccountType.local;
      case 'miniflux':
        return AccountType.miniflux;
      case 'fever':
        return AccountType.fever;
      case 'googleReader':
        return AccountType.googleReader;
      default:
        throw ArgumentError('Unknown account type: $wire');
    }
  }
}
