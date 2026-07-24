import 'dart:ui';
import '../data/models/column_model.dart';
import '../data/models/table_model.dart';
import '../data/models/relationship_model.dart';
import 'sql_dialect.dart';
import 'sql_dialect_generator.dart';

class SqlserverGenerator implements SqlDialectGenerator {
  @override
  SqlDialect get dialect => SqlDialect.sqlserver;

  @override
  String generateDdl(List<TableModel> tables, List<RelationshipModel> relationships) {
    final buffer = StringBuffer();
    buffer.writeln('-- Script SQL gerado para SQL Server (T-SQL)');
    buffer.writeln('-- Data: ${DateTime.now().toIso8601String()}');
    buffer.writeln();

    for (final table in tables) {
      final schema = table.schema.isNotEmpty ? table.schema : 'dbo';
      final tableName = '[$schema].[${table.name}]';

      buffer.writeln('CREATE TABLE $tableName (');
      final colDefs = <String>[];

      for (final col in table.columns) {
        var def = '    [${col.name}] ${col.dataType}';
        if (col.lengthOrPrecision != null && col.lengthOrPrecision!.isNotEmpty) {
          def += '(${col.lengthOrPrecision})';
        }
        if (col.isAutoIncrement) {
          def += ' IDENTITY(1,1)';
        }
        if (col.isNotNull) {
          def += ' NOT NULL';
        } else {
          def += ' NULL';
        }
        if (col.isUnique) {
          def += ' UNIQUE';
        }
        colDefs.add(def);
      }

      final pks = table.primaryKeys;
      if (pks.isNotEmpty) {
        final pkCols = pks.map((c) => '[${c.name}]').join(', ');
        colDefs.add('    CONSTRAINT [PK_${table.name}] PRIMARY KEY CLUSTERED ($pkCols)');
      }

      buffer.writeln(colDefs.join(',\n'));
      buffer.writeln(');');
      buffer.writeln('GO');
      buffer.writeln();
    }

    // Foreign Keys
    for (final rel in relationships) {
      final sourceTable = tables.firstWhere(
        (t) => t.id == rel.sourceTableId,
        orElse: () => TableModel(id: '', name: 'unknown', position: Offset.zero, columns: []),
      );
      final targetTable = tables.firstWhere(
        (t) => t.id == rel.targetTableId,
        orElse: () => TableModel(id: '', name: 'unknown', position: Offset.zero, columns: []),
      );
      final sourceCol = sourceTable.columns.firstWhere(
        (c) => c.id == rel.sourceColumnId,
        orElse: () => const ColumnModel(id: '', name: 'id', dataType: 'INT'),
      );
      final targetCol = targetTable.columns.firstWhere(
        (c) => c.id == rel.targetColumnId,
        orElse: () => const ColumnModel(id: '', name: 'id', dataType: 'INT'),
      );

      final sourceSchema = sourceTable.schema.isNotEmpty ? sourceTable.schema : 'dbo';
      final targetSchema = targetTable.schema.isNotEmpty ? targetTable.schema : 'dbo';
      final fkName = rel.name ?? 'FK_${sourceTable.name}_${targetTable.name}';

      buffer.writeln('ALTER TABLE [$sourceSchema].[${sourceTable.name}]');
      buffer.writeln('    ADD CONSTRAINT [$fkName]');
      buffer.writeln('    FOREIGN KEY ([${sourceCol.name}])');
      buffer.writeln('    REFERENCES [$targetSchema].[${targetTable.name}] ([${targetCol.name}])');
      buffer.writeln('    ON DELETE ${rel.onDelete.sqlKeyword}');
      buffer.writeln('    ON UPDATE ${rel.onUpdate.sqlKeyword};');
      buffer.writeln('GO');
      buffer.writeln();
    }

    return buffer.toString();
  }
}
