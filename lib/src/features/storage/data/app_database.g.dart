// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $NotebookEntriesTable extends NotebookEntries
    with TableInfo<$NotebookEntriesTable, NotebookRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotebookEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _wordMeta = const VerificationMeta('word');
  @override
  late final GeneratedColumn<String> word = GeneratedColumn<String>(
      'word', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sentenceMeta =
      const VerificationMeta('sentence');
  @override
  late final GeneratedColumn<String> sentence = GeneratedColumn<String>(
      'sentence', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _meaningMeta =
      const VerificationMeta('meaning');
  @override
  late final GeneratedColumn<String> meaning = GeneratedColumn<String>(
      'meaning', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMsMeta =
      const VerificationMeta('timestampMs');
  @override
  late final GeneratedColumn<int> timestampMs = GeneratedColumn<int>(
      'timestamp_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _videoIdMeta =
      const VerificationMeta('videoId');
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
      'video_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _analysisJsonMeta =
      const VerificationMeta('analysisJson');
  @override
  late final GeneratedColumn<String> analysisJson = GeneratedColumn<String>(
      'analysis_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        word,
        sentence,
        meaning,
        timestampMs,
        source,
        videoId,
        analysisJson,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notebook_entries';
  @override
  VerificationContext validateIntegrity(Insertable<NotebookRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('word')) {
      context.handle(
          _wordMeta, word.isAcceptableOrUnknown(data['word']!, _wordMeta));
    } else if (isInserting) {
      context.missing(_wordMeta);
    }
    if (data.containsKey('sentence')) {
      context.handle(_sentenceMeta,
          sentence.isAcceptableOrUnknown(data['sentence']!, _sentenceMeta));
    } else if (isInserting) {
      context.missing(_sentenceMeta);
    }
    if (data.containsKey('meaning')) {
      context.handle(_meaningMeta,
          meaning.isAcceptableOrUnknown(data['meaning']!, _meaningMeta));
    } else if (isInserting) {
      context.missing(_meaningMeta);
    }
    if (data.containsKey('timestamp_ms')) {
      context.handle(
          _timestampMsMeta,
          timestampMs.isAcceptableOrUnknown(
              data['timestamp_ms']!, _timestampMsMeta));
    } else if (isInserting) {
      context.missing(_timestampMsMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('video_id')) {
      context.handle(_videoIdMeta,
          videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta));
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('analysis_json')) {
      context.handle(
          _analysisJsonMeta,
          analysisJson.isAcceptableOrUnknown(
              data['analysis_json']!, _analysisJsonMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NotebookRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotebookRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      word: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}word'])!,
      sentence: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sentence'])!,
      meaning: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}meaning'])!,
      timestampMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}timestamp_ms'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      videoId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}video_id'])!,
      analysisJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}analysis_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $NotebookEntriesTable createAlias(String alias) {
    return $NotebookEntriesTable(attachedDatabase, alias);
  }
}

class NotebookRow extends DataClass implements Insertable<NotebookRow> {
  final String id;
  final String word;
  final String sentence;
  final String meaning;
  final int timestampMs;
  final String source;
  final String videoId;

  /// Full serialized [AnalysisResult] so cards can render the complete
  /// word + sentence breakdown and support re-analysis.
  final String analysisJson;
  final DateTime createdAt;
  const NotebookRow(
      {required this.id,
      required this.word,
      required this.sentence,
      required this.meaning,
      required this.timestampMs,
      required this.source,
      required this.videoId,
      required this.analysisJson,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['word'] = Variable<String>(word);
    map['sentence'] = Variable<String>(sentence);
    map['meaning'] = Variable<String>(meaning);
    map['timestamp_ms'] = Variable<int>(timestampMs);
    map['source'] = Variable<String>(source);
    map['video_id'] = Variable<String>(videoId);
    map['analysis_json'] = Variable<String>(analysisJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  NotebookEntriesCompanion toCompanion(bool nullToAbsent) {
    return NotebookEntriesCompanion(
      id: Value(id),
      word: Value(word),
      sentence: Value(sentence),
      meaning: Value(meaning),
      timestampMs: Value(timestampMs),
      source: Value(source),
      videoId: Value(videoId),
      analysisJson: Value(analysisJson),
      createdAt: Value(createdAt),
    );
  }

  factory NotebookRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotebookRow(
      id: serializer.fromJson<String>(json['id']),
      word: serializer.fromJson<String>(json['word']),
      sentence: serializer.fromJson<String>(json['sentence']),
      meaning: serializer.fromJson<String>(json['meaning']),
      timestampMs: serializer.fromJson<int>(json['timestampMs']),
      source: serializer.fromJson<String>(json['source']),
      videoId: serializer.fromJson<String>(json['videoId']),
      analysisJson: serializer.fromJson<String>(json['analysisJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'word': serializer.toJson<String>(word),
      'sentence': serializer.toJson<String>(sentence),
      'meaning': serializer.toJson<String>(meaning),
      'timestampMs': serializer.toJson<int>(timestampMs),
      'source': serializer.toJson<String>(source),
      'videoId': serializer.toJson<String>(videoId),
      'analysisJson': serializer.toJson<String>(analysisJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  NotebookRow copyWith(
          {String? id,
          String? word,
          String? sentence,
          String? meaning,
          int? timestampMs,
          String? source,
          String? videoId,
          String? analysisJson,
          DateTime? createdAt}) =>
      NotebookRow(
        id: id ?? this.id,
        word: word ?? this.word,
        sentence: sentence ?? this.sentence,
        meaning: meaning ?? this.meaning,
        timestampMs: timestampMs ?? this.timestampMs,
        source: source ?? this.source,
        videoId: videoId ?? this.videoId,
        analysisJson: analysisJson ?? this.analysisJson,
        createdAt: createdAt ?? this.createdAt,
      );
  NotebookRow copyWithCompanion(NotebookEntriesCompanion data) {
    return NotebookRow(
      id: data.id.present ? data.id.value : this.id,
      word: data.word.present ? data.word.value : this.word,
      sentence: data.sentence.present ? data.sentence.value : this.sentence,
      meaning: data.meaning.present ? data.meaning.value : this.meaning,
      timestampMs:
          data.timestampMs.present ? data.timestampMs.value : this.timestampMs,
      source: data.source.present ? data.source.value : this.source,
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      analysisJson: data.analysisJson.present
          ? data.analysisJson.value
          : this.analysisJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotebookRow(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('sentence: $sentence, ')
          ..write('meaning: $meaning, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('source: $source, ')
          ..write('videoId: $videoId, ')
          ..write('analysisJson: $analysisJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, word, sentence, meaning, timestampMs,
      source, videoId, analysisJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotebookRow &&
          other.id == this.id &&
          other.word == this.word &&
          other.sentence == this.sentence &&
          other.meaning == this.meaning &&
          other.timestampMs == this.timestampMs &&
          other.source == this.source &&
          other.videoId == this.videoId &&
          other.analysisJson == this.analysisJson &&
          other.createdAt == this.createdAt);
}

class NotebookEntriesCompanion extends UpdateCompanion<NotebookRow> {
  final Value<String> id;
  final Value<String> word;
  final Value<String> sentence;
  final Value<String> meaning;
  final Value<int> timestampMs;
  final Value<String> source;
  final Value<String> videoId;
  final Value<String> analysisJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const NotebookEntriesCompanion({
    this.id = const Value.absent(),
    this.word = const Value.absent(),
    this.sentence = const Value.absent(),
    this.meaning = const Value.absent(),
    this.timestampMs = const Value.absent(),
    this.source = const Value.absent(),
    this.videoId = const Value.absent(),
    this.analysisJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotebookEntriesCompanion.insert({
    required String id,
    required String word,
    required String sentence,
    required String meaning,
    required int timestampMs,
    required String source,
    required String videoId,
    this.analysisJson = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        word = Value(word),
        sentence = Value(sentence),
        meaning = Value(meaning),
        timestampMs = Value(timestampMs),
        source = Value(source),
        videoId = Value(videoId),
        createdAt = Value(createdAt);
  static Insertable<NotebookRow> custom({
    Expression<String>? id,
    Expression<String>? word,
    Expression<String>? sentence,
    Expression<String>? meaning,
    Expression<int>? timestampMs,
    Expression<String>? source,
    Expression<String>? videoId,
    Expression<String>? analysisJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (word != null) 'word': word,
      if (sentence != null) 'sentence': sentence,
      if (meaning != null) 'meaning': meaning,
      if (timestampMs != null) 'timestamp_ms': timestampMs,
      if (source != null) 'source': source,
      if (videoId != null) 'video_id': videoId,
      if (analysisJson != null) 'analysis_json': analysisJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotebookEntriesCompanion copyWith(
      {Value<String>? id,
      Value<String>? word,
      Value<String>? sentence,
      Value<String>? meaning,
      Value<int>? timestampMs,
      Value<String>? source,
      Value<String>? videoId,
      Value<String>? analysisJson,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return NotebookEntriesCompanion(
      id: id ?? this.id,
      word: word ?? this.word,
      sentence: sentence ?? this.sentence,
      meaning: meaning ?? this.meaning,
      timestampMs: timestampMs ?? this.timestampMs,
      source: source ?? this.source,
      videoId: videoId ?? this.videoId,
      analysisJson: analysisJson ?? this.analysisJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (word.present) {
      map['word'] = Variable<String>(word.value);
    }
    if (sentence.present) {
      map['sentence'] = Variable<String>(sentence.value);
    }
    if (meaning.present) {
      map['meaning'] = Variable<String>(meaning.value);
    }
    if (timestampMs.present) {
      map['timestamp_ms'] = Variable<int>(timestampMs.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (analysisJson.present) {
      map['analysis_json'] = Variable<String>(analysisJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotebookEntriesCompanion(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('sentence: $sentence, ')
          ..write('meaning: $meaning, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('source: $source, ')
          ..write('videoId: $videoId, ')
          ..write('analysisJson: $analysisJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $NotebookEntriesTable notebookEntries =
      $NotebookEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [notebookEntries];
}

typedef $$NotebookEntriesTableCreateCompanionBuilder = NotebookEntriesCompanion
    Function({
  required String id,
  required String word,
  required String sentence,
  required String meaning,
  required int timestampMs,
  required String source,
  required String videoId,
  Value<String> analysisJson,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$NotebookEntriesTableUpdateCompanionBuilder = NotebookEntriesCompanion
    Function({
  Value<String> id,
  Value<String> word,
  Value<String> sentence,
  Value<String> meaning,
  Value<int> timestampMs,
  Value<String> source,
  Value<String> videoId,
  Value<String> analysisJson,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$NotebookEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $NotebookEntriesTable> {
  $$NotebookEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get word => $composableBuilder(
      column: $table.word, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sentence => $composableBuilder(
      column: $table.sentence, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get meaning => $composableBuilder(
      column: $table.meaning, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get timestampMs => $composableBuilder(
      column: $table.timestampMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get videoId => $composableBuilder(
      column: $table.videoId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get analysisJson => $composableBuilder(
      column: $table.analysisJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$NotebookEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotebookEntriesTable> {
  $$NotebookEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get word => $composableBuilder(
      column: $table.word, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sentence => $composableBuilder(
      column: $table.sentence, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get meaning => $composableBuilder(
      column: $table.meaning, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get timestampMs => $composableBuilder(
      column: $table.timestampMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get videoId => $composableBuilder(
      column: $table.videoId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get analysisJson => $composableBuilder(
      column: $table.analysisJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$NotebookEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotebookEntriesTable> {
  $$NotebookEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get word =>
      $composableBuilder(column: $table.word, builder: (column) => column);

  GeneratedColumn<String> get sentence =>
      $composableBuilder(column: $table.sentence, builder: (column) => column);

  GeneratedColumn<String> get meaning =>
      $composableBuilder(column: $table.meaning, builder: (column) => column);

  GeneratedColumn<int> get timestampMs => $composableBuilder(
      column: $table.timestampMs, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get analysisJson => $composableBuilder(
      column: $table.analysisJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$NotebookEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NotebookEntriesTable,
    NotebookRow,
    $$NotebookEntriesTableFilterComposer,
    $$NotebookEntriesTableOrderingComposer,
    $$NotebookEntriesTableAnnotationComposer,
    $$NotebookEntriesTableCreateCompanionBuilder,
    $$NotebookEntriesTableUpdateCompanionBuilder,
    (
      NotebookRow,
      BaseReferences<_$AppDatabase, $NotebookEntriesTable, NotebookRow>
    ),
    NotebookRow,
    PrefetchHooks Function()> {
  $$NotebookEntriesTableTableManager(
      _$AppDatabase db, $NotebookEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotebookEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotebookEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotebookEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> word = const Value.absent(),
            Value<String> sentence = const Value.absent(),
            Value<String> meaning = const Value.absent(),
            Value<int> timestampMs = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String> videoId = const Value.absent(),
            Value<String> analysisJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NotebookEntriesCompanion(
            id: id,
            word: word,
            sentence: sentence,
            meaning: meaning,
            timestampMs: timestampMs,
            source: source,
            videoId: videoId,
            analysisJson: analysisJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String word,
            required String sentence,
            required String meaning,
            required int timestampMs,
            required String source,
            required String videoId,
            Value<String> analysisJson = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              NotebookEntriesCompanion.insert(
            id: id,
            word: word,
            sentence: sentence,
            meaning: meaning,
            timestampMs: timestampMs,
            source: source,
            videoId: videoId,
            analysisJson: analysisJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$NotebookEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $NotebookEntriesTable,
    NotebookRow,
    $$NotebookEntriesTableFilterComposer,
    $$NotebookEntriesTableOrderingComposer,
    $$NotebookEntriesTableAnnotationComposer,
    $$NotebookEntriesTableCreateCompanionBuilder,
    $$NotebookEntriesTableUpdateCompanionBuilder,
    (
      NotebookRow,
      BaseReferences<_$AppDatabase, $NotebookEntriesTable, NotebookRow>
    ),
    NotebookRow,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$NotebookEntriesTableTableManager get notebookEntries =>
      $$NotebookEntriesTableTableManager(_db, _db.notebookEntries);
}
