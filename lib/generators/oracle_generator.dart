import 'dart:ui';
import '../data/models/column_model.dart';
import '../data/models/table_model.dart';
import '../data/models/relationship_model.dart';
import 'sql_dialect.dart';
import 'sql_dialect_generator.dart';

class OracleGenerator implements SqlDialectGenerator {
  @override
  SqlDialect get dialect => SqlDialect.oracle;

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
    buffer.writeln('-- Script SQL gerado para Oracle DB');
    buffer.writeln('-- Data: ${DateTime.now().toIso8601String()}');
    buffer.writeln();

    final sortedTables = _sortTablesByDependency(tables, relationships);

    for (final table in sortedTables) {
      final tableName = table.name.toUpperCase();
      buffer.writeln('CREATE TABLE "$tableName" (');
      final colDefs = <String>[];

      for (final col in table.columns) {
        final colName = col.name.toUpperCase();
        var def = '    "$colName" ${col.dataType}';
        if (col.lengthOrPrecision != null && col.lengthOrPrecision!.isNotEmpty) {
          def += '(${col.lengthOrPrecision})';
        }
        if (col.isAutoIncrement) {
          def += ' GENERATED ALWAYS AS IDENTITY';
        }
        if (col.isNotNull) {
          def += ' NOT NULL';
        }
        if (col.isUnique) {
          def += ' UNIQUE';
        }
        colDefs.add(def);
      }

      final pks = table.primaryKeys;
      if (pks.isNotEmpty) {
        final pkCols = pks.map((c) => '"${c.name.toUpperCase()}"').join(', ');
        colDefs.add('    CONSTRAINT "PK_$tableName" PRIMARY KEY ($pkCols)');
      }

      buffer.writeln(colDefs.join(',\n'));
      buffer.writeln(');');
      buffer.writeln();
    }

    // Foreign Keys
    // Na UI: arrastar de A para B significa "B referencia A"
    // Então: fkTable = target (tem a FK), refTable = source (tem a PK)
    for (final rel in relationships) {
      final refTable = tables.firstWhere(
        (t) => t.id == rel.sourceTableId,
        orElse: () => TableModel(id: '', name: 'unknown', position: Offset.zero, columns: []),
      );
      final fkTable = tables.firstWhere(
        (t) => t.id == rel.targetTableId,
        orElse: () => TableModel(id: '', name: 'unknown', position: Offset.zero, columns: []),
      );
      final refCol = refTable.columns.firstWhere(
        (c) => c.id == rel.sourceColumnId,
        orElse: () => const ColumnModel(id: '', name: 'id', dataType: 'NUMBER'),
      );
      final fkCol = fkTable.columns.firstWhere(
        (c) => c.id == rel.targetColumnId,
        orElse: () => const ColumnModel(id: '', name: 'id', dataType: 'NUMBER'),
      );

      // Garantir que a coluna referenciada tenha UNIQUE ou PRIMARY KEY
      if (!refCol.isPrimaryKey && !refCol.isUnique) {
        final rName = refTable.name.toUpperCase();
        buffer.writeln('-- Adicionar UNIQUE na coluna referenciada para suportar FK');
        buffer.writeln('ALTER TABLE "$rName"');
        buffer.writeln('    ADD CONSTRAINT "UQ_${rName}_${refCol.name.toUpperCase()}"');
        buffer.writeln('    UNIQUE ("${refCol.name.toUpperCase()}");');
        buffer.writeln();
      }

      final fName = fkTable.name.toUpperCase();
      final rName = refTable.name.toUpperCase();
      final fkName = (rel.name ?? 'FK_${fName}_$rName').toUpperCase();

      buffer.writeln('ALTER TABLE "$fName"');
      buffer.writeln('    ADD CONSTRAINT "$fkName"');
      buffer.writeln('    FOREIGN KEY ("${fkCol.name.toUpperCase()}")');
      buffer.writeln('    REFERENCES "$rName" ("${refCol.name.toUpperCase()}")');
      buffer.writeln('    ON DELETE ${rel.onDelete.sqlKeyword};');
      buffer.writeln();
    }

    return buffer.toString();
  }
}
