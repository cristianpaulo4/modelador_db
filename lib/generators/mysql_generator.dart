import 'dart:ui';
import '../data/models/column_model.dart';
import '../data/models/table_model.dart';
import '../data/models/relationship_model.dart';
import 'sql_dialect.dart';
import 'sql_dialect_generator.dart';

class MysqlGenerator implements SqlDialectGenerator {
  @override
  SqlDialect get dialect => SqlDialect.mysql;

  @override
  String generateDdl(List<TableModel> tables, List<RelationshipModel> relationships) {
    final buffer = StringBuffer();
    buffer.writeln('-- Script SQL gerado para MySQL / MariaDB');
    buffer.writeln('-- Data: ${DateTime.now().toIso8601String()}');
    buffer.writeln();

    for (final table in tables) {
      buffer.writeln('CREATE TABLE `${table.name}` (');
      final colDefs = <String>[];

      for (final col in table.columns) {
        var def = '  `${col.name}` ${col.dataType}';
        if (col.lengthOrPrecision != null && col.lengthOrPrecision!.isNotEmpty) {
          def += '(${col.lengthOrPrecision})';
        }
        if (col.isNotNull) {
          def += ' NOT NULL';
        }
        if (col.isAutoIncrement) {
          def += ' AUTO_INCREMENT';
        }
        if (col.isUnique) {
          def += ' UNIQUE';
        }
        if (col.defaultValue != null && col.defaultValue!.isNotEmpty) {
          def += ' DEFAULT ${col.defaultValue}';
        }
        colDefs.add(def);
      }

      final pks = table.primaryKeys;
      if (pks.isNotEmpty) {
        final pkCols = pks.map((c) => '`${c.name}`').join(', ');
        colDefs.add('  PRIMARY KEY ($pkCols)');
      }

      buffer.writeln(colDefs.join(',\n'));
      buffer.writeln(') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;');
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

      // Garantir que a coluna de destino tenha UNIQUE ou PRIMARY KEY
      if (!targetCol.isPrimaryKey && !targetCol.isUnique) {
        buffer.writeln('-- Adicionar UNIQUE na coluna de destino para suportar FK');
        buffer.writeln('ALTER TABLE `${targetTable.name}`');
        buffer.writeln('  ADD UNIQUE INDEX `uq_${targetTable.name}_${targetCol.name}` (`${targetCol.name}`);');
        buffer.writeln();
      }

      final fkName = rel.name ?? 'fk_${sourceTable.name}_${targetTable.name}';
      buffer.writeln('ALTER TABLE `${sourceTable.name}`');
      buffer.writeln('  ADD CONSTRAINT `$fkName`');
      buffer.writeln('  FOREIGN KEY (`${sourceCol.name}`)');
      buffer.writeln('  REFERENCES `${targetTable.name}` (`${targetCol.name}`)');
      buffer.writeln('  ON DELETE ${rel.onDelete.sqlKeyword}');
      buffer.writeln('  ON UPDATE ${rel.onUpdate.sqlKeyword};');
      buffer.writeln();
    }

    return buffer.toString();
  }
}
