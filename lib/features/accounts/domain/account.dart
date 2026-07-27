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
    this.deletionPending = false,
  });

  static const googleReaderGenericProfileId = 'googleReaderGeneric';
  static const _reservedDatabaseNames = <String>{'fleur', 'flutter_reader'};
  static final _validDatabaseName = RegExp(r'^[a-zA-Z0-9._-]+$');

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

  // Persisted before destructive cleanup so an interrupted deletion can be
  // resumed without exposing an account whose database may already be gone.
  final bool deletionPending;

  String get isolatedDatabaseName {
    return isolatedDatabaseNameFor(accountId: id, dbName: dbName);
  }

  static String isolatedDatabaseNameFor({
    required String accountId,
    String? dbName,
  }) {
    final explicit = dbName?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      final collisionKey = databaseNameCollisionKey(explicit);
      if (!_validDatabaseName.hasMatch(explicit) ||
          explicit == '.' ||
          explicit == '..') {
        throw FormatException('Invalid account database name: $explicit');
      }
      if (_reservedDatabaseNames.contains(collisionKey)) {
        throw FormatException(
          'Account database name is reserved for the primary account: '
          '$explicit',
        );
      }
      return explicit;
    }

    final sanitized = accountId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return 'fleur_$sanitized';
  }

  static String databaseNameCollisionKey(String name) =>
      name.trim().toLowerCase();

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
    bool? deletionPending,
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
      deletionPending: deletionPending ?? this.deletionPending,
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
      deletionPending: (json['deletionPending'] as bool?) ?? false,
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
      'deletionPending': deletionPending,
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
