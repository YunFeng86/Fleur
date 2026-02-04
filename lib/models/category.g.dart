// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetCategoryCollection on Isar {
  IsarCollection<Category> get categorys => this.collection();
}

const CategorySchema = CollectionSchema(
  name: r'Category',
  id: 5751694338128944171,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'filterEnabled': PropertySchema(
      id: 1,
      name: r'filterEnabled',
      type: IsarType.bool,
    ),
    r'filterKeywords': PropertySchema(
      id: 2,
      name: r'filterKeywords',
      type: IsarType.string,
    ),
    r'name': PropertySchema(id: 3, name: r'name', type: IsarType.string),
    r'showAiSummary': PropertySchema(
      id: 4,
      name: r'showAiSummary',
      type: IsarType.bool,
    ),
    r'syncEnabled': PropertySchema(
      id: 5,
      name: r'syncEnabled',
      type: IsarType.bool,
    ),
    r'syncImages': PropertySchema(
      id: 6,
      name: r'syncImages',
      type: IsarType.bool,
    ),
    r'syncWebPages': PropertySchema(
      id: 7,
      name: r'syncWebPages',
      type: IsarType.bool,
    ),
    r'updatedAt': PropertySchema(
      id: 8,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
  },
  estimateSize: _categoryEstimateSize,
  serialize: _categorySerialize,
  deserialize: _categoryDeserialize,
  deserializeProp: _categoryDeserializeProp,
  idName: r'id',
  indexes: {
    r'name': IndexSchema(
      id: 879695947855722453,
      name: r'name',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'name',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},
  getId: _categoryGetId,
  getLinks: _categoryGetLinks,
  attach: _categoryAttach,
  version: '3.1.0+1',
);

int _categoryEstimateSize(
  Category object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.filterKeywords;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.name.length * 3;
  return bytesCount;
}

void _categorySerialize(
  Category object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeBool(offsets[1], object.filterEnabled);
  writer.writeString(offsets[2], object.filterKeywords);
  writer.writeString(offsets[3], object.name);
  writer.writeBool(offsets[4], object.showAiSummary);
  writer.writeBool(offsets[5], object.syncEnabled);
  writer.writeBool(offsets[6], object.syncImages);
  writer.writeBool(offsets[7], object.syncWebPages);
  writer.writeDateTime(offsets[8], object.updatedAt);
}

Category _categoryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Category();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.filterEnabled = reader.readBoolOrNull(offsets[1]);
  object.filterKeywords = reader.readStringOrNull(offsets[2]);
  object.id = id;
  object.name = reader.readString(offsets[3]);
  object.showAiSummary = reader.readBoolOrNull(offsets[4]);
  object.syncEnabled = reader.readBoolOrNull(offsets[5]);
  object.syncImages = reader.readBoolOrNull(offsets[6]);
  object.syncWebPages = reader.readBoolOrNull(offsets[7]);
  object.updatedAt = reader.readDateTime(offsets[8]);
  return object;
}

P _categoryDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readBoolOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readBoolOrNull(offset)) as P;
    case 5:
      return (reader.readBoolOrNull(offset)) as P;
    case 6:
      return (reader.readBoolOrNull(offset)) as P;
    case 7:
      return (reader.readBoolOrNull(offset)) as P;
    case 8:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _categoryGetId(Category object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _categoryGetLinks(Category object) {
  return [];
}

void _categoryAttach(IsarCollection<dynamic> col, Id id, Category object) {
  object.id = id;
}

extension CategoryByIndex on IsarCollection<Category> {
  Future<Category?> getByName(String name) {
    return getByIndex(r'name', [name]);
  }

  Category? getByNameSync(String name) {
    return getByIndexSync(r'name', [name]);
  }

  Future<bool> deleteByName(String name) {
    return deleteByIndex(r'name', [name]);
  }

  bool deleteByNameSync(String name) {
    return deleteByIndexSync(r'name', [name]);
  }

  Future<List<Category?>> getAllByName(List<String> nameValues) {
    final values = nameValues.map((e) => [e]).toList();
    return getAllByIndex(r'name', values);
  }

  List<Category?> getAllByNameSync(List<String> nameValues) {
    final values = nameValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'name', values);
  }

  Future<int> deleteAllByName(List<String> nameValues) {
    final values = nameValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'name', values);
  }

  int deleteAllByNameSync(List<String> nameValues) {
    final values = nameValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'name', values);
  }

  Future<Id> putByName(Category object) {
    return putByIndex(r'name', object);
  }

  Id putByNameSync(Category object, {bool saveLinks = true}) {
    return putByIndexSync(r'name', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByName(List<Category> objects) {
    return putAllByIndex(r'name', objects);
  }

  List<Id> putAllByNameSync(List<Category> objects, {bool saveLinks = true}) {
    return putAllByIndexSync(r'name', objects, saveLinks: saveLinks);
  }
}

extension CategoryQueryWhereSort on QueryBuilder<Category, Category, QWhere> {
  QueryBuilder<Category, Category, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension CategoryQueryWhere on QueryBuilder<Category, Category, QWhereClause> {
  QueryBuilder<Category, Category, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<Category, Category, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<Category, Category, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterWhereClause> idBetween(
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

  QueryBuilder<Category, Category, QAfterWhereClause> nameEqualTo(String name) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'name', value: [name]),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterWhereClause> nameNotEqualTo(
    String name,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'name',
                lower: [],
                upper: [name],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'name',
                lower: [name],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'name',
                lower: [name],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'name',
                lower: [],
                upper: [name],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension CategoryQueryFilter
    on QueryBuilder<Category, Category, QFilterCondition> {
  QueryBuilder<Category, Category, QAfterFilterCondition> createdAtEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> createdAtGreaterThan(
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

  QueryBuilder<Category, Category, QAfterFilterCondition> createdAtLessThan(
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

  QueryBuilder<Category, Category, QAfterFilterCondition> createdAtBetween(
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

  QueryBuilder<Category, Category, QAfterFilterCondition>
  filterEnabledIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'filterEnabled'),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition>
  filterEnabledIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'filterEnabled'),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> filterEnabledEqualTo(
    bool? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'filterEnabled', value: value),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition>
  filterKeywordsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'filterKeywords'),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition>
  filterKeywordsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'filterKeywords'),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> filterKeywordsEqualTo(
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

  QueryBuilder<Category, Category, QAfterFilterCondition>
  filterKeywordsGreaterThan(
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

  QueryBuilder<Category, Category, QAfterFilterCondition>
  filterKeywordsLessThan(
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

  QueryBuilder<Category, Category, QAfterFilterCondition> filterKeywordsBetween(
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

  QueryBuilder<Category, Category, QAfterFilterCondition>
  filterKeywordsStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<Category, Category, QAfterFilterCondition>
  filterKeywordsEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<Category, Category, QAfterFilterCondition>
  filterKeywordsContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<Category, Category, QAfterFilterCondition> filterKeywordsMatches(
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

  QueryBuilder<Category, Category, QAfterFilterCondition>
  filterKeywordsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'filterKeywords', value: ''),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition>
  filterKeywordsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'filterKeywords', value: ''),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<Category, Category, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<Category, Category, QAfterFilterCondition> idBetween(
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

  QueryBuilder<Category, Category, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> nameContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> nameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition>
  showAiSummaryIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'showAiSummary'),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition>
  showAiSummaryIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'showAiSummary'),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> showAiSummaryEqualTo(
    bool? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'showAiSummary', value: value),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> syncEnabledIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'syncEnabled'),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition>
  syncEnabledIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'syncEnabled'),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> syncEnabledEqualTo(
    bool? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'syncEnabled', value: value),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> syncImagesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'syncImages'),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition>
  syncImagesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'syncImages'),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> syncImagesEqualTo(
    bool? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'syncImages', value: value),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> syncWebPagesIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'syncWebPages'),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition>
  syncWebPagesIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'syncWebPages'),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> syncWebPagesEqualTo(
    bool? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'syncWebPages', value: value),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> updatedAtEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> updatedAtGreaterThan(
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

  QueryBuilder<Category, Category, QAfterFilterCondition> updatedAtLessThan(
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

  QueryBuilder<Category, Category, QAfterFilterCondition> updatedAtBetween(
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
}

extension CategoryQueryObject
    on QueryBuilder<Category, Category, QFilterCondition> {}

extension CategoryQueryLinks
    on QueryBuilder<Category, Category, QFilterCondition> {}

extension CategoryQuerySortBy on QueryBuilder<Category, Category, QSortBy> {
  QueryBuilder<Category, Category, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> sortByFilterEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filterEnabled', Sort.asc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> sortByFilterEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filterEnabled', Sort.desc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> sortByFilterKeywords() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filterKeywords', Sort.asc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> sortByFilterKeywordsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filterKeywords', Sort.desc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> sortByShowAiSummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showAiSummary', Sort.asc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> sortByShowAiSummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showAiSummary', Sort.desc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> sortBySyncEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncEnabled', Sort.asc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> sortBySyncEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncEnabled', Sort.desc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> sortBySyncImages() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncImages', Sort.asc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> sortBySyncImagesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncImages', Sort.desc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> sortBySyncWebPages() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncWebPages', Sort.asc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> sortBySyncWebPagesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncWebPages', Sort.desc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension CategoryQuerySortThenBy
    on QueryBuilder<Category, Category, QSortThenBy> {
  QueryBuilder<Category, Category, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> thenByFilterEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filterEnabled', Sort.asc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> thenByFilterEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filterEnabled', Sort.desc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> thenByFilterKeywords() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filterKeywords', Sort.asc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> thenByFilterKeywordsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filterKeywords', Sort.desc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> thenByShowAiSummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showAiSummary', Sort.asc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> thenByShowAiSummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'showAiSummary', Sort.desc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> thenBySyncEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncEnabled', Sort.asc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> thenBySyncEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncEnabled', Sort.desc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> thenBySyncImages() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncImages', Sort.asc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> thenBySyncImagesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncImages', Sort.desc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> thenBySyncWebPages() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncWebPages', Sort.asc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> thenBySyncWebPagesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncWebPages', Sort.desc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension CategoryQueryWhereDistinct
    on QueryBuilder<Category, Category, QDistinct> {
  QueryBuilder<Category, Category, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<Category, Category, QDistinct> distinctByFilterEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'filterEnabled');
    });
  }

  QueryBuilder<Category, Category, QDistinct> distinctByFilterKeywords({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'filterKeywords',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Category, Category, QDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Category, Category, QDistinct> distinctByShowAiSummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'showAiSummary');
    });
  }

  QueryBuilder<Category, Category, QDistinct> distinctBySyncEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncEnabled');
    });
  }

  QueryBuilder<Category, Category, QDistinct> distinctBySyncImages() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncImages');
    });
  }

  QueryBuilder<Category, Category, QDistinct> distinctBySyncWebPages() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncWebPages');
    });
  }

  QueryBuilder<Category, Category, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension CategoryQueryProperty
    on QueryBuilder<Category, Category, QQueryProperty> {
  QueryBuilder<Category, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Category, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<Category, bool?, QQueryOperations> filterEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'filterEnabled');
    });
  }

  QueryBuilder<Category, String?, QQueryOperations> filterKeywordsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'filterKeywords');
    });
  }

  QueryBuilder<Category, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<Category, bool?, QQueryOperations> showAiSummaryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'showAiSummary');
    });
  }

  QueryBuilder<Category, bool?, QQueryOperations> syncEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncEnabled');
    });
  }

  QueryBuilder<Category, bool?, QQueryOperations> syncImagesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncImages');
    });
  }

  QueryBuilder<Category, bool?, QQueryOperations> syncWebPagesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncWebPages');
    });
  }

  QueryBuilder<Category, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
