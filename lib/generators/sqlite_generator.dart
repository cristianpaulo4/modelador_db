import 'dart:ui';
import '../data/models/column_model.dart';
import '../data/models/table_model.dart';
import '../data/models/relationship_model.dart';
import 'sql_dialect.dart';
import 'sql_dialect_generator.dart';

class SqliteGenerator implements SqlDialectGenerator {
  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  String generateDdl(List<TableModel> tables, List<RelationshipModel> relationships) {
    final buffer = StringBuffer();
    buffer.writeln('-- Script SQL gerado para SQLite');
    buffer.writeln('-- Data: ${DateTime.now().toIso8601String()}');
    buffer.writeln('PRAGMA foreign_keys = ON;');
    buffer.writeln();

    for (final table in tables) {
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
      final tableRels = relationships.where((r) => r.sourceTableId == table.id);
      for (final rel in tableRels) {
        final targetTable = tables.firstWhere(
          (t) => t.id == rel.targetTableId,
          orElse: () => TableModel(id: '', name: 'unknown', position: Offset.zero, columns: []),
        );
        final sourceCol = table.columns.firstWhere(
          (c) => c.id == rel.sourceColumnId,
          orElse: () => const ColumnModel(id: '', name: 'id', dataType: 'INTEGER'),
        );
        final targetCol = targetTable.columns.firstWhere(
          (c) => c.id == rel.targetColumnId,
          orElse: () => const ColumnModel(id: '', name: 'id', dataType: 'INTEGER'),
        );

        colDefs.add(
          '  FOREIGN KEY ("${sourceCol.name}") REFERENCES "${targetTable.name}" ("${targetCol.name}") ON DELETE ${rel.onDelete.sqlKeyword} ON UPDATE ${rel.onUpdate.sqlKeyword}',
        );
      }

      buffer.writeln(colDefs.join(',\n'));
      buffer.writeln(');');
      buffer.writeln();
    }

    return buffer.toString();
  }
}
