class Account {
  Account({
    required this.id,
    required this.type,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.baseUrl,
    this.profileId,
    this.dbName,
    this.isPrimary = false,
    this.databaseInitialized = true,
  });

  static const googleReaderGenericProfileId = 'googleReaderGeneric';

  final String id;
  final AccountType type;
  final String name;

  // Remote service base URL (for Miniflux/Fever), e.g. https://rss.example.com
  final String? baseUrl;

  // Optional non-secret provider/profile discriminator. Google Reader compatible
  // accounts use this to distinguish provider dialects without splitting AccountType.
  final String? profileId;

  // For per-account DB isolation. Primary account uses legacy-safe resolver and
  // may leave this null.
  final String? dbName;

  // Primary means "open existing DB with PathManager.getIsarLocation()" to
  // avoid silent data loss during migration.
  final bool isPrimary;

  // Existing serialized accounts default to true. Only explicitly new
  // accounts may initialize a missing database.
  final bool databaseInitialized;

  String get isolatedDatabaseName {
    final explicit = dbName?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return 'fleur_$id';
  }

  final DateTime createdAt;
  final DateTime updatedAt;

  Account copyWith({
    String? id,
    AccountType? type,
    String? name,
    String? baseUrl,
    String? profileId,
    String? dbName,
    bool? isPrimary,
    bool? databaseInitialized,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      profileId: profileId ?? this.profileId,
      dbName: dbName ?? this.dbName,
      isPrimary: isPrimary ?? this.isPrimary,
      databaseInitialized: databaseInitialized ?? this.databaseInitialized,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static Account fromJson(Map<String, Object?> json) {
    final type = AccountTypeX.fromWire(json['type'] as String);
    final rawProfileId = json['profileId'] as String?;
    return Account(
      id: json['id'] as String,
      type: type,
      name: json['name'] as String,
      baseUrl: json['baseUrl'] as String?,
      profileId: _profileIdFromJson(type, rawProfileId),
      dbName: json['dbName'] as String?,
      isPrimary: (json['isPrimary'] as bool?) ?? false,
      databaseInitialized: (json['databaseInitialized'] as bool?) ?? true,
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
      'profileId': profileId,
      'dbName': dbName,
      'isPrimary': isPrimary,
      'databaseInitialized': databaseInitialized,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static String? _profileIdFromJson(AccountType type, String? raw) {
    final trimmed = raw?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    if (type == AccountType.googleReader) return googleReaderGenericProfileId;
    return null;
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
