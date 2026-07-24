import 'dart:ui';
import '../data/models/column_model.dart';
import '../data/models/table_model.dart';
import '../data/models/relationship_model.dart';
import 'sql_dialect.dart';
import 'sql_dialect_generator.dart';

class OracleGenerator implements SqlDialectGenerator {
  @override
  SqlDialect get dialect => SqlDialect.oracle;

  @override
  String generateDdl(List<TableModel> tables, List<RelationshipModel> relationships) {
    final buffer = StringBuffer();
    buffer.writeln('-- Script SQL gerado para Oracle DB');
    buffer.writeln('-- Data: ${DateTime.now().toIso8601String()}');
    buffer.writeln();

    for (final table in tables) {
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
        orElse: () => const ColumnModel(id: '', name: 'id', dataType: 'NUMBER'),
      );
      final targetCol = targetTable.columns.firstWhere(
        (c) => c.id == rel.targetColumnId,
        orElse: () => const ColumnModel(id: '', name: 'id', dataType: 'NUMBER'),
      );

      // Garantir que a coluna de destino tenha UNIQUE ou PRIMARY KEY
      if (!targetCol.isPrimaryKey && !targetCol.isUnique) {
        final tName = targetTable.name.toUpperCase();
        buffer.writeln('-- Adicionar UNIQUE na coluna de destino para suportar FK');
        buffer.writeln('ALTER TABLE "$tName"');
        buffer.writeln('    ADD CONSTRAINT "UQ_${tName}_${targetCol.name.toUpperCase()}"');
        buffer.writeln('    UNIQUE ("${targetCol.name.toUpperCase()}");');
        buffer.writeln();
      }

      final sName = sourceTable.name.toUpperCase();
      final tName = targetTable.name.toUpperCase();
      final fkName = (rel.name ?? 'FK_${sName}_$tName').toUpperCase();

      buffer.writeln('ALTER TABLE "$sName"');
      buffer.writeln('    ADD CONSTRAINT "$fkName"');
      buffer.writeln('    FOREIGN KEY ("${sourceCol.name.toUpperCase()}")');
      buffer.writeln('    REFERENCES "$tName" ("${targetCol.name.toUpperCase()}")');
      buffer.writeln('    ON DELETE ${rel.onDelete.sqlKeyword};');
      buffer.writeln();
    }

    return buffer.toString();
  }
}
