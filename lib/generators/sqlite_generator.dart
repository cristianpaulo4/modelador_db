import 'dart:ui';
import '../data/models/column_model.dart';
import '../data/models/table_model.dart';
import '../data/models/relationship_model.dart';
import 'sql_dialect.dart';
import 'sql_dialect_generator.dart';

class SqliteGenerator implements SqlDialectGenerator {
  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  /// Ordena tabelas por dependência (topological sort)
  List<TableModel> _sortTablesByDependency(
    List<TableModel> tables,
    List<RelationshipModel> relationships,
  ) {
    final tableMap = {for (final t in tables) t.id: t};
    final dependencies = <String, Set<String>>{};
    for (final table in tables) {
      dependencies[table.id] = {};
    }
    for (final rel in relationships) {
      final fkTableId = rel.targetTableId;
      final refTableId = rel.sourceTableId;
      if (dependencies.containsKey(fkTableId)) {
        dependencies[fkTableId]!.add(refTableId);
      }
    }

    final inDegree = <String, int>{};
    for (final tableId in dependencies.keys) {
      inDegree[tableId] = dependencies[tableId]!.length;
    }

    final queue = <String>[];
    for (final entry in inDegree.entries) {
      if (entry.value == 0) queue.add(entry.key);
    }

    final sorted = <TableModel>[];
    while (queue.isNotEmpty) {
      final currentId = queue.removeAt(0);
      final table = tableMap[currentId];
      if (table != null) sorted.add(table);

      for (final entry in dependencies.entries) {
        if (entry.value.contains(currentId)) {
          inDegree[entry.key] = inDegree[entry.key]! - 1;
          if (inDegree[entry.key] == 0) queue.add(entry.key);
        }
      }
    }

    for (final table in tables) {
      if (!sorted.any((t) => t.id == table.id)) sorted.add(table);
    }

    return sorted;
  }

  @override
  String generateDdl(List<TableModel> tables, List<RelationshipModel> relationships) {
    final buffer = StringBuffer();
    buffer.writeln('-- Script SQL gerado para SQLite');
    buffer.writeln('-- Data: ${DateTime.now().toIso8601String()}');
    buffer.writeln('PRAGMA foreign_keys = ON;');
    buffer.writeln();

    // No SQLite, ALTER TABLE ADD CONSTRAINT não é suportado.
    // Para garantir unicidade em colunas referenciadas para FKs que não são PK/Unique,
    // devemos usar CREATE UNIQUE INDEX após a criação das tabelas.
    final uniqueIndexes = <String>[];
    for (final rel in relationships) {
      final refTable = tables.firstWhere(
        (t) => t.id == rel.sourceTableId,
        orElse: () => TableModel(id: '', name: 'unknown', position: Offset.zero, columns: []),
      );
      final refCol = refTable.columns.firstWhere(
        (c) => c.id == rel.sourceColumnId,
        orElse: () => const ColumnModel(id: '', name: 'id', dataType: 'INTEGER'),
      );

      if (!refCol.isPrimaryKey && !refCol.isUnique) {
        uniqueIndexes.add(
          'CREATE UNIQUE INDEX IF NOT EXISTS "idx_uq_${refTable.name}_${refCol.name}" ON "${refTable.name}" ("${refCol.name}");',
        );
      }
    }

    // Ordenar tabelas por dependência
    final sortedTables = _sortTablesByDependency(tables, relationships);

    for (final table in sortedTables) {
      buffer.writeln('CREATE TABLE IF NOT EXISTS "${table.name}" (');
      final colDefs = <String>[];
      final pks = table.primaryKeys;
      final isCompositePk = pks.length > 1;

      for (final col in table.columns) {
        var dataType = col.dataType;
        // No SQLite, AUTOINCREMENT só é permitido em coluna INTEGER PRIMARY KEY
        if (!isCompositePk && col.isPrimaryKey && col.isAutoIncrement && dataType.toUpperCase() != 'INTEGER') {
          dataType = 'INTEGER';
        }

        var def = '  "${col.name}" $dataType';
        if (col.isPrimaryKey && !isCompositePk) {
          def += ' PRIMARY KEY';
          if (col.isAutoIncrement) {
            def += ' AUTOINCREMENT';
          }
        }
        if (col.isNotNull) {
          def += ' NOT NULL';
        }
        if (col.isUnique && (!col.isPrimaryKey || isCompositePk)) {
          def += ' UNIQUE';
        }
        if (col.defaultValue != null && col.defaultValue!.isNotEmpty && !col.isAutoIncrement) {
          var defaultVal = col.defaultValue!.trim();
          if (defaultVal.toLowerCase() == 'now()' || defaultVal.toLowerCase() == 'now') {
            defaultVal = 'CURRENT_TIMESTAMP';
          } else if (defaultVal.toLowerCase().contains('gen_random_uuid') || defaultVal.toLowerCase().contains('uuid_generate')) {
            defaultVal = "(lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))),2) || '-' || substr('89ab',abs(random()) % 4 + 1, 1) || substr(lower(hex(randomblob(2))),2) || '-' || lower(hex(randomblob(6))))";
          }
          def += ' DEFAULT $defaultVal';
        }
        colDefs.add(def);
      }

      if (isCompositePk) {
        final pkCols = pks.map((c) => '"${c.name}"').join(', ');
        colDefs.add('  PRIMARY KEY ($pkCols)');
      }

      // Foreign Keys inline no SQLite
      // fkTable = target (tem a FK), refTable = source (tem a PK)
      final tableRels = relationships.where((r) => r.targetTableId == table.id);
      for (final rel in tableRels) {
        final refTable = tables.firstWhere(
          (t) => t.id == rel.sourceTableId,
          orElse: () => TableModel(id: '', name: 'unknown', position: Offset.zero, columns: []),
        );
        final fkCol = table.columns.firstWhere(
          (c) => c.id == rel.targetColumnId,
          orElse: () => const ColumnModel(id: '', name: 'id', dataType: 'INTEGER'),
        );
        final refCol = refTable.columns.firstWhere(
          (c) => c.id == rel.sourceColumnId,
          orElse: () => const ColumnModel(id: '', name: 'id', dataType: 'INTEGER'),
        );

        colDefs.add(
          '  FOREIGN KEY ("${fkCol.name}") REFERENCES "${refTable.name}" ("${refCol.name}") ON DELETE ${rel.onDelete.sqlKeyword} ON UPDATE ${rel.onUpdate.sqlKeyword}',
        );
      }

      buffer.writeln(colDefs.join(',\n'));
      buffer.writeln(');');
      buffer.writeln();
    }

    if (uniqueIndexes.isNotEmpty) {
      buffer.writeln('-- Garantir UNIQUE nas colunas referenciadas para FKs');
      for (final idx in uniqueIndexes) {
        buffer.writeln(idx);
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}
