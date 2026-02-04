// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetFeedCollection on Isar {
  IsarCollection<Feed> get feeds => this.collection();
}

const FeedSchema = CollectionSchema(
  name: r'Feed',
  id: 8879644747771893978,
  properties: {
    r'categoryId': PropertySchema(
      id: 0,
      name: r'categoryId',
      type: IsarType.long,
    ),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'description': PropertySchema(
      id: 2,
      name: r'description',
      type: IsarType.string,
    ),
    r'etag': PropertySchema(id: 3, name: r'etag', type: IsarType.string),
    r'filterEnabled': PropertySchema(
      id: 4,
      name: r'filterEnabled',
      type: IsarType.bool,
    ),
    r'filterKeywords': PropertySchema(
      id: 5,
      name: r'filterKeywords',
      type: IsarType.string,
    ),
    r'lastCheckedAt': PropertySchema(
      id: 6,
      name: r'lastCheckedAt',
      type: IsarType.dateTime,
    ),
    r'lastDurationMs': PropertySchema(
      id: 7,
      name: r'lastDurationMs',
      type: IsarType.long,
    ),
    r'lastError': PropertySchema(
      id: 8,
      name: r'lastError',
      type: IsarType.string,
    ),
    r'lastErrorAt': PropertySchema(
      id: 9,
      name: r'lastErrorAt',
      type: IsarType.dateTime,
    ),
    r'lastIncomingCount': PropertySchema(
      id: 10,
      name: r'lastIncomingCount',
      type: IsarType.long,
    ),
    r'lastModified': PropertySchema(
      id: 11,
      name: r'lastModified',
      type: IsarType.string,
    ),
    r'lastStatusCode': PropertySchema(
      id: 12,
      name: r'lastStatusCode',
      type: IsarType.long,
    ),
    r'lastSyncedAt': PropertySchema(
      id: 13,
      name: r'lastSyncedAt',
      type: IsarType.dateTime,
    ),
    r'showAiSummary': PropertySchema(
      id: 14,
      name: r'showAiSummary',
      type: IsarType.bool,
    ),
    r'siteUrl': PropertySchema(id: 15, name: r'siteUrl', type: IsarType.string),
    r'syncEnabled': PropertySchema(
      id: 16,
      name: r'syncEnabled',
      type: IsarType.bool,
    ),
    r'syncImages': PropertySchema(
      id: 17,
      name: r'syncImages',
      type: IsarType.bool,
    ),
    r'syncWebPages': PropertySchema(
      id: 18,
      name: r'syncWebPages',
      type: IsarType.bool,
    ),
    r'title': PropertySchema(id: 19, name: r'title', type: IsarType.string),
    r'updatedAt': PropertySchema(
      id: 20,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'url': PropertySchema(id: 21, name: r'url', type: IsarType.string),
    r'userTitle': PropertySchema(
      id: 22,
      name: r'userTitle',
      type: IsarType.string,
    ),
  },
  estimateSize: _feedEstimateSize,
  serialize: _feedSerialize,
  deserialize: _feedDeserialize,
  deserializeProp: _feedDeserializeProp,
  idName: r'id',
  indexes: {
    r'url': IndexSchema(
      id: -5756857009679432345,
      name: r'url',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'url',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'categoryId': IndexSchema(
      id: -8798048739239305339,
      name: r'categoryId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'categoryId',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},
  getId: _feedGetId,
  getLinks: _feedGetLinks,
  attach: _feedAttach,
  version: '3.1.0+1',
);

int _feedEstimateSize(
  Feed object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.description;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.etag;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.filterKeywords;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.lastError;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.lastModified;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.siteUrl;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.title;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.url.length * 3;
  {
    final value = object.userTitle;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _feedSerialize(
  Feed object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.categoryId);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeString(offsets[2], object.description);
  writer.writeString(offsets[3], object.etag);
  writer.writeBool(offsets[4], object.filterEnabled);
  writer.writeString(offsets[5], object.filterKeywords);
  writer.writeDateTime(offsets[6], object.lastCheckedAt);
  writer.writeLong(offsets[7], object.lastDurationMs);
  writer.writeString(offsets[8], object.lastError);
  writer.writeDateTime(offsets[9], object.lastErrorAt);
  writer.writeLong(offsets[10], object.lastIncomingCount);
  writer.writeString(offsets[11], object.lastModified);
  writer.writeLong(offsets[12], object.lastStatusCode);
  writer.writeDateTime(offsets[13], object.lastSyncedAt);
  writer.writeBool(offsets[14], object.showAiSummary);
  writer.writeString(offsets[15], object.siteUrl);
  writer.writeBool(offsets[16], object.syncEnabled);
  writer.writeBool(offsets[17], object.syncImages);
  writer.writeBool(offsets[18], object.syncWebPages);
  writer.writeString(offsets[19], object.title);
  writer.writeDateTime(offsets[20], object.updatedAt);
  writer.writeString(offsets[21], object.url);
  writer.writeString(offsets[22], object.userTitle);
}

Feed _feedDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Feed();
  object.categoryId = reader.readLongOrNull(offsets[0]);
  object.createdAt = reader.readDateTime(offsets[1]);
  object.description = reader.readStringOrNull(offsets[2]);
  object.etag = reader.readStringOrNull(offsets[3]);
  object.filterEnabled = reader.readBoolOrNull(offsets[4]);
  object.filterKeywords = reader.readStringOrNull(offsets[5]);
  object.id = id;
  object.lastCheckedAt = reader.readDateTimeOrNull(offsets[6]);
  object.lastDurationMs = reader.readLongOrNull(offsets[7]);
  object.lastError = reader.readStringOrNull(offsets[8]);
  object.lastErrorAt = reader.readDateTimeOrNull(offsets[9]);
  object.lastIncomingCount = reader.readLongOrNull(offsets[10]);
  object.lastModified = reader.readStringOrNull(offsets[11]);
  object.lastStatusCode = reader.readLongOrNull(offsets[12]);
  object.lastSyncedAt = reader.readDateTimeOrNull(offsets[13]);
  object.showAiSummary = reader.readBoolOrNull(offsets[14]);
  object.siteUrl = reader.readStringOrNull(offsets[15]);
  object.syncEnabled = reader.readBoolOrNull(offsets[16]);
  object.syncImages = reader.readBoolOrNull(offsets[17]);
  object.syncWebPages = reader.readBoolOrNull(offsets[18]);
  object.title = reader.readStringOrNull(offsets[19]);
  object.updatedAt = reader.readDateTime(offsets[20]);
  object.url = reader.readString(offsets[21]);
  object.userTitle = reader.readStringOrNull(offsets[22]);
  return object;
}

P _feedDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongOrNull(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readBoolOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 7:
      return (reader.readLongOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 10:
      return (reader.readLongOrNull(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readLongOrNull(offset)) as P;
    case 13:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 14:
      return (reader.readBoolOrNull(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readBoolOrNull(offset)) as P;
    case 17:
      return (reader.readBoolOrNull(offset)) as P;
    case 18:
      return (reader.readBoolOrNull(offset)) as P;
    case 19:
      return (reader.readStringOrNull(offset)) as P;
    case 20:
      return (reader.readDateTime(offset)) as P;
    case 21:
      return (reader.readString(offset)) as P;
    case 22:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _feedGetId(Feed object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _feedGetLinks(Feed object) {
  return [];
}

void _feedAttach(IsarCollection<dynamic> col, Id id, Feed object) {
  object.id = id;
}

extension FeedByIndex on IsarCollection<Feed> {
  Future<Feed?> getByUrl(String url) {
    return getByIndex(r'url', [url]);
  }

  Feed? getByUrlSync(String url) {
    return getByIndexSync(r'url', [url]);
  }

  Future<bool> deleteByUrl(String url) {
    return deleteByIndex(r'url', [url]);
  }

  bool deleteByUrlSync(String url) {
    return deleteByIndexSync(r'url', [url]);
  }

  Future<List<Feed?>> getAllByUrl(List<String> urlValues) {
    final values = urlValues.map((e) => [e]).toList();
    return getAllByIndex(r'url', values);
  }

  List<Feed?> getAllByUrlSync(List<String> urlValues) {
    final values = urlValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'url', values);
  }

  Future<int> deleteAllByUrl(List<String> urlValues) {
    final values = urlValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'url', values);
  }

  int deleteAllByUrlSync(List<String> urlValues) {
    final values = urlValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'url', values);
  }

  Future<Id> putByUrl(Feed object) {
    return putByIndex(r'url', object);
  }

  Id putByUrlSync(Feed object, {bool saveLinks = true}) {
    return putByIndexSync(r'url', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByUrl(List<Feed> objects) {
    return putAllByIndex(r'url', objects);
  }

  List<Id> putAllByUrlSync(List<Feed> objects, {bool saveLinks = true}) {
    return putAllByIndexSync(r'url', objects, saveLinks: saveLinks);
  }
}

extension FeedQueryWhereSort on QueryBuilder<Feed, Feed, QWhere> {
  QueryBuilder<Feed, Feed, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<Feed, Feed, QAfterWhere> anyCategoryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'categoryId'),
      );
    });
  }
}

extension FeedQueryWhere on QueryBuilder<Feed, Feed, QWhereClause> {
  QueryBuilder<Feed, Feed, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<Feed, Feed, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Feed, Feed, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterWhereClause> urlEqualTo(String url) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'url', value: [url]),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterWhereClause> urlNotEqualTo(String url) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'url',
                lower: [],
                upper: [url],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'url',
                lower: [url],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'url',
                lower: [url],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'url',
                lower: [],
                upper: [url],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Feed, Feed, QAfterWhereClause> categoryIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'categoryId', value: [null]),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterWhereClause> categoryIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'categoryId',
          lower: [null],
          includeLower: false,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterWhereClause> categoryIdEqualTo(
    int? categoryId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'categoryId', value: [categoryId]),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterWhereClause> categoryIdNotEqualTo(
    int? categoryId,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'categoryId',
                lower: [],
                upper: [categoryId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'categoryId',
                lower: [categoryId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'categoryId',
                lower: [categoryId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'categoryId',
                lower: [],
                upper: [categoryId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<Feed, Feed, QAfterWhereClause> categoryIdGreaterThan(
    int? categoryId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'categoryId',
          lower: [categoryId],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterWhereClause> categoryIdLessThan(
    int? categoryId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'categoryId',
          lower: [],
          upper: [categoryId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterWhereClause> categoryIdBetween(
    int? lowerCategoryId,
    int? upperCategoryId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'categoryId',
          lower: [lowerCategoryId],
          includeLower: includeLower,
          upper: [upperCategoryId],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension FeedQueryFilter on QueryBuilder<Feed, Feed, QFilterCondition> {
  QueryBuilder<Feed, Feed, QAfterFilterCondition> categoryIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'categoryId'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> categoryIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'categoryId'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> categoryIdEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'categoryId', value: value),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> categoryIdGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'categoryId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> categoryIdLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'categoryId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> categoryIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'categoryId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> createdAtEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> descriptionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'description'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> descriptionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'description'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> descriptionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> descriptionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> descriptionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> descriptionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'description',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> descriptionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> descriptionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> descriptionContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'description',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> descriptionMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'description',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> descriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'description', value: ''),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> descriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'description', value: ''),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> etagIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'etag'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> etagIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'etag'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> etagEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'etag',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> etagGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'etag',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> etagLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'etag',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> etagBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'etag',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> etagStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'etag',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> etagEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'etag',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> etagContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'etag',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> etagMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'etag',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> etagIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'etag', value: ''),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> etagIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'etag', value: ''),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> filterEnabledIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'filterEnabled'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> filterEnabledIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'filterEnabled'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> filterEnabledEqualTo(
    bool? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'filterEnabled', value: value),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> filterKeywordsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'filterKeywords'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> filterKeywordsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'filterKeywords'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> filterKeywordsEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'filterKeywords',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> filterKeywordsGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'filterKeywords',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> filterKeywordsLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'filterKeywords',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> filterKeywordsBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'filterKeywords',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> filterKeywordsStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'filterKeywords',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> filterKeywordsEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'filterKeywords',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> filterKeywordsContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'filterKeywords',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> filterKeywordsMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'filterKeywords',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> filterKeywordsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'filterKeywords', value: ''),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> filterKeywordsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'filterKeywords', value: ''),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastCheckedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastCheckedAt'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastCheckedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastCheckedAt'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastCheckedAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastCheckedAt', value: value),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastCheckedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastCheckedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastCheckedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastCheckedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastCheckedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastCheckedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastDurationMsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastDurationMs'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastDurationMsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastDurationMs'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastDurationMsEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastDurationMs', value: value),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastDurationMsGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastDurationMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastDurationMsLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastDurationMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastDurationMsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastDurationMs',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastErrorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastError'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastErrorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastError'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastErrorEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'lastError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastErrorGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastErrorLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastErrorBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastError',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastErrorStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'lastError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastErrorEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'lastError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastErrorContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'lastError',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastErrorMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'lastError',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastErrorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastError', value: ''),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastErrorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'lastError', value: ''),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastErrorAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastErrorAt'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastErrorAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastErrorAt'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastErrorAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastErrorAt', value: value),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastErrorAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastErrorAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastErrorAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastErrorAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastErrorAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastErrorAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastIncomingCountIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastIncomingCount'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastIncomingCountIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastIncomingCount'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastIncomingCountEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastIncomingCount', value: value),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastIncomingCountGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastIncomingCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastIncomingCountLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastIncomingCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastIncomingCountBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastIncomingCount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastModifiedIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastModified'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastModifiedIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastModified'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastModifiedEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'lastModified',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastModifiedGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastModified',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastModifiedLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastModified',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastModifiedBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastModified',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastModifiedStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'lastModified',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastModifiedEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'lastModified',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastModifiedContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'lastModified',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastModifiedMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'lastModified',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastModifiedIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastModified', value: ''),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastModifiedIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'lastModified', value: ''),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastStatusCodeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastStatusCode'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastStatusCodeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastStatusCode'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastStatusCodeEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastStatusCode', value: value),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastStatusCodeGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastStatusCode',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastStatusCodeLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastStatusCode',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastStatusCodeBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastStatusCode',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastSyncedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastSyncedAt'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastSyncedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastSyncedAt'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastSyncedAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastSyncedAt', value: value),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastSyncedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastSyncedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastSyncedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastSyncedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> lastSyncedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastSyncedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> showAiSummaryIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'showAiSummary'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> showAiSummaryIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'showAiSummary'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> showAiSummaryEqualTo(
    bool? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'showAiSummary', value: value),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> siteUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'siteUrl'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> siteUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'siteUrl'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> siteUrlEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'siteUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> siteUrlGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'siteUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> siteUrlLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'siteUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> siteUrlBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'siteUrl',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> siteUrlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'siteUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> siteUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'siteUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> siteUrlContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'siteUrl',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> siteUrlMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'siteUrl',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> siteUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'siteUrl', value: ''),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> siteUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'siteUrl', value: ''),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> syncEnabledIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'syncEnabled'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> syncEnabledIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'syncEnabled'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> syncEnabledEqualTo(
    bool? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'syncEnabled', value: value),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> syncImagesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'syncImages'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> syncImagesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'syncImages'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> syncImagesEqualTo(
    bool? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'syncImages', value: value),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> syncWebPagesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'syncWebPages'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> syncWebPagesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'syncWebPages'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> syncWebPagesEqualTo(
    bool? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'syncWebPages', value: value),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> titleIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'title'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> titleIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'title'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> titleEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> titleGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> titleLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> titleBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'title',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> titleContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> titleMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'title',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> updatedAtEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> updatedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> updatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> urlEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'url',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> urlGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'url',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> urlLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'url',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> urlBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'url',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> urlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'url',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> urlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'url',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> urlContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'url',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> urlMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'url',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> urlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'url', value: ''),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> urlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'url', value: ''),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> userTitleIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'userTitle'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> userTitleIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'userTitle'),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> userTitleEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'userTitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> userTitleGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'userTitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> userTitleLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'userTitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> userTitleBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'userTitle',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> userTitleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'userTitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> userTitleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'userTitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> userTitleContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'userTitle',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> userTitleMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'userTitle',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> userTitleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'userTitle', value: ''),
      );
    });
  }

  QueryBuilder<Feed, Feed, QAfterFilterCondition> userTitleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'userTitle', value: ''),
      );
    });
  }
}

extension FeedQueryObject on QueryBuilder<Feed, Feed, QFilterCondition> {}

extension FeedQueryLinks on QueryBuilder<Feed, Feed, QFilterCondition> {}

extension FeedQuerySortBy on QueryBuilder<Feed, Feed, QSortBy> {
  QueryBuilder<Feed, Feed, QAfterSortBy> sortByCategoryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryId', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByCategoryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryId', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByEtag() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'etag', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByEtagDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'etag', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByFilterEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filterEnabled', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByFilterEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filterEnabled', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByFilterKeywords() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filterKeywords', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByFilterKeywordsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filterKeywords', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByLastCheckedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastCheckedAt', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByLastCheckedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastCheckedAt', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByLastDurationMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastDurationMs', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByLastDurationMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastDurationMs', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByLastError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastError', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByLastErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastError', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByLastErrorAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastErrorAt', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByLastErrorAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastErrorAt', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByLastIncomingCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastIncomingCount', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByLastIncomingCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastIncomingCount', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByLastModified() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModified', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByLastModifiedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModified', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByLastStatusCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastStatusCode', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByLastStatusCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastStatusCode', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByLastSyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncedAt', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByLastSyncedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncedAt', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByShowAiSummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showAiSummary', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByShowAiSummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showAiSummary', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortBySiteUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'siteUrl', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortBySiteUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'siteUrl', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortBySyncEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncEnabled', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortBySyncEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncEnabled', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortBySyncImages() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncImages', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortBySyncImagesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncImages', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortBySyncWebPages() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncWebPages', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortBySyncWebPagesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncWebPages', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'url', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'url', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByUserTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userTitle', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> sortByUserTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userTitle', Sort.desc);
    });
  }
}

extension FeedQuerySortThenBy on QueryBuilder<Feed, Feed, QSortThenBy> {
  QueryBuilder<Feed, Feed, QAfterSortBy> thenByCategoryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryId', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByCategoryIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'categoryId', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByEtag() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'etag', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByEtagDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'etag', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByFilterEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filterEnabled', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByFilterEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filterEnabled', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByFilterKeywords() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filterKeywords', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByFilterKeywordsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filterKeywords', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByLastCheckedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastCheckedAt', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByLastCheckedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastCheckedAt', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByLastDurationMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastDurationMs', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByLastDurationMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastDurationMs', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByLastError() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastError', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByLastErrorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastError', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByLastErrorAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastErrorAt', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByLastErrorAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastErrorAt', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByLastIncomingCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastIncomingCount', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByLastIncomingCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastIncomingCount', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByLastModified() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModified', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByLastModifiedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModified', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByLastStatusCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastStatusCode', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByLastStatusCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastStatusCode', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByLastSyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncedAt', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByLastSyncedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncedAt', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByShowAiSummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showAiSummary', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByShowAiSummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showAiSummary', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenBySiteUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'siteUrl', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenBySiteUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'siteUrl', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenBySyncEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncEnabled', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenBySyncEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncEnabled', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenBySyncImages() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncImages', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenBySyncImagesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncImages', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenBySyncWebPages() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncWebPages', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenBySyncWebPagesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncWebPages', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'url', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'url', Sort.desc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByUserTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userTitle', Sort.asc);
    });
  }

  QueryBuilder<Feed, Feed, QAfterSortBy> thenByUserTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userTitle', Sort.desc);
    });
  }
}

extension FeedQueryWhereDistinct on QueryBuilder<Feed, Feed, QDistinct> {
  QueryBuilder<Feed, Feed, QDistinct> distinctByCategoryId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'categoryId');
    });
  }

  QueryBuilder<Feed, Feed, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<Feed, Feed, QDistinct> distinctByDescription({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'description', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Feed, Feed, QDistinct> distinctByEtag({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'etag', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Feed, Feed, QDistinct> distinctByFilterEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'filterEnabled');
    });
  }

  QueryBuilder<Feed, Feed, QDistinct> distinctByFilterKeywords({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'filterKeywords',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Feed, Feed, QDistinct> distinctByLastCheckedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastCheckedAt');
    });
  }

  QueryBuilder<Feed, Feed, QDistinct> distinctByLastDurationMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastDurationMs');
    });
  }

  QueryBuilder<Feed, Feed, QDistinct> distinctByLastError({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastError', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Feed, Feed, QDistinct> distinctByLastErrorAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastErrorAt');
    });
  }

  QueryBuilder<Feed, Feed, QDistinct> distinctByLastIncomingCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastIncomingCount');
    });
  }

  QueryBuilder<Feed, Feed, QDistinct> distinctByLastModified({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastModified', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Feed, Feed, QDistinct> distinctByLastStatusCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastStatusCode');
    });
  }

  QueryBuilder<Feed, Feed, QDistinct> distinctByLastSyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastSyncedAt');
    });
  }

  QueryBuilder<Feed, Feed, QDistinct> distinctByShowAiSummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'showAiSummary');
    });
  }

  QueryBuilder<Feed, Feed, QDistinct> distinctBySiteUrl({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'siteUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Feed, Feed, QDistinct> distinctBySyncEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncEnabled');
    });
  }

  QueryBuilder<Feed, Feed, QDistinct> distinctBySyncImages() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncImages');
    });
  }

  QueryBuilder<Feed, Feed, QDistinct> distinctBySyncWebPages() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncWebPages');
    });
  }

  QueryBuilder<Feed, Feed, QDistinct> distinctByTitle({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Feed, Feed, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }

  QueryBuilder<Feed, Feed, QDistinct> distinctByUrl({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'url', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Feed, Feed, QDistinct> distinctByUserTitle({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'userTitle', caseSensitive: caseSensitive);
    });
  }
}

extension FeedQueryProperty on QueryBuilder<Feed, Feed, QQueryProperty> {
  QueryBuilder<Feed, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Feed, int?, QQueryOperations> categoryIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'categoryId');
    });
  }

  QueryBuilder<Feed, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<Feed, String?, QQueryOperations> descriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'description');
    });
  }

  QueryBuilder<Feed, String?, QQueryOperations> etagProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'etag');
    });
  }

  QueryBuilder<Feed, bool?, QQueryOperations> filterEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'filterEnabled');
    });
  }

  QueryBuilder<Feed, String?, QQueryOperations> filterKeywordsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'filterKeywords');
    });
  }

  QueryBuilder<Feed, DateTime?, QQueryOperations> lastCheckedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastCheckedAt');
    });
  }

  QueryBuilder<Feed, int?, QQueryOperations> lastDurationMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastDurationMs');
    });
  }

  QueryBuilder<Feed, String?, QQueryOperations> lastErrorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastError');
    });
  }

  QueryBuilder<Feed, DateTime?, QQueryOperations> lastErrorAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastErrorAt');
    });
  }

  QueryBuilder<Feed, int?, QQueryOperations> lastIncomingCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastIncomingCount');
    });
  }

  QueryBuilder<Feed, String?, QQueryOperations> lastModifiedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastModified');
    });
  }

  QueryBuilder<Feed, int?, QQueryOperations> lastStatusCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastStatusCode');
    });
  }

  QueryBuilder<Feed, DateTime?, QQueryOperations> lastSyncedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSyncedAt');
    });
  }

  QueryBuilder<Feed, bool?, QQueryOperations> showAiSummaryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'showAiSummary');
    });
  }

  QueryBuilder<Feed, String?, QQueryOperations> siteUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'siteUrl');
    });
  }

  QueryBuilder<Feed, bool?, QQueryOperations> syncEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncEnabled');
    });
  }

  QueryBuilder<Feed, bool?, QQueryOperations> syncImagesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncImages');
    });
  }

  QueryBuilder<Feed, bool?, QQueryOperations> syncWebPagesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncWebPages');
    });
  }

  QueryBuilder<Feed, String?, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<Feed, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<Feed, String, QQueryOperations> urlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'url');
    });
  }

  QueryBuilder<Feed, String?, QQueryOperations> userTitleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'userTitle');
    });
  }
}
