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

    // Primeiro, garantir UNIQUE nas colunas referenciadas que precisam
    // Na UI: arrastar de A para B significa "B referencia A"
    // Então: refTable = source (tem a PK), fkTable = target (tem a FK)
    final uniqueConstraints = <String>[];
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
        uniqueConstraints.add(
          'ALTER TABLE "${refTable.name}" ADD CONSTRAINT "uq_${refTable.name}_${refCol.name}" UNIQUE ("${refCol.name}");',
        );
      }
    }

    if (uniqueConstraints.isNotEmpty) {
      buffer.writeln('-- Garantir UNIQUE nas colunas referenciadas para FKs');
      for (final constraint in uniqueConstraints) {
        buffer.writeln(constraint);
      }
      buffer.writeln();
    }

    // Ordenar tabelas por dependência
    final sortedTables = _sortTablesByDependency(tables, relationships);

    for (final table in sortedTables) {
      buffer.writeln('CREATE TABLE IF NOT EXISTS "${table.name}" (');
      final colDefs = <String>[];

      for (final col in table.columns) {
        var def = '  "${col.name}" ${col.dataType}';
        if (col.isPrimaryKey) {
          def += ' PRIMARY KEY';
          if (col.isAutoIncrement) {
            def += ' AUTOINCREMENT';
          }
        }
        if (col.isNotNull) {
          def += ' NOT NULL';
        }
        if (col.isUnique && !col.isPrimaryKey) {
          def += ' UNIQUE';
        }
        if (col.defaultValue != null && col.defaultValue!.isNotEmpty) {
          def += ' DEFAULT ${col.defaultValue}';
        }
        colDefs.add(def);
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

    return buffer.toString();
  }
}
