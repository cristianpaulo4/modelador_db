import 'dart:ui';
import '../data/models/column_model.dart';
import '../data/models/table_model.dart';
import '../data/models/relationship_model.dart';
import 'sql_dialect.dart';
import 'sql_dialect_generator.dart';

class PostgresqlGenerator implements SqlDialectGenerator {
  @override
  SqlDialect get dialect => SqlDialect.postgres;

  /// Ordena tabelas por dependência (topological sort)
  /// Tabelas sem dependências vêm primeiro
  List<TableModel> _sortTablesByDependency(
    List<TableModel> tables,
    List<RelationshipModel> relationships,
  ) {
    // Mapear ID -> TableModel
    final tableMap = {for (final t in tables) t.id: t};

    // Construir grafo de dependências: fkTableId -> Set de refTableIds
    final dependencies = <String, Set<String>>{};
    for (final table in tables) {
      dependencies[table.id] = {};
    }
    for (final rel in relationships) {
      // targetTable depende de sourceTable (target referencia source)
      final fkTableId = rel.targetTableId;
      final refTableId = rel.sourceTableId;
      if (dependencies.containsKey(fkTableId)) {
        dependencies[fkTableId]!.add(refTableId);
      }
    }

    // Topological sort (Kahn's algorithm)
    final inDegree = <String, int>{};
    for (final tableId in dependencies.keys) {
      inDegree[tableId] = dependencies[tableId]!.length;
    }

    final queue = <String>[];
    for (final entry in inDegree.entries) {
      if (entry.value == 0) {
        queue.add(entry.key);
      }
    }

    final sorted = <TableModel>[];
    while (queue.isNotEmpty) {
      final currentId = queue.removeAt(0);
      final table = tableMap[currentId];
      if (table != null) {
        sorted.add(table);
      }

      // Reduzir grau de dependência das tabelas que dependem desta
      for (final entry in dependencies.entries) {
        if (entry.value.contains(currentId)) {
          inDegree[entry.key] = inDegree[entry.key]! - 1;
          if (inDegree[entry.key] == 0) {
            queue.add(entry.key);
          }
        }
      }
    }

    // Adicionar tabelas que não foram processadas (ciclos ou isoladas)
    for (final table in tables) {
      if (!sorted.any((t) => t.id == table.id)) {
        sorted.add(table);
      }
    }

    return sorted;
  }

  @override
  String generateDdl(List<TableModel> tables, List<RelationshipModel> relationships) {
    final buffer = StringBuffer();
    buffer.writeln('-- Script SQL gerado para PostgreSQL');
    buffer.writeln('-- Data: ${DateTime.now().toIso8601String()}');
    buffer.writeln();

    // Ordenar tabelas por dependência
    final sortedTables = _sortTablesByDependency(tables, relationships);

    for (final table in sortedTables) {
      final tableName = table.schema.isNotEmpty && table.schema != 'public'
          ? '"${table.schema}"."${table.name}"'
          : '"${table.name}"';

      buffer.writeln('CREATE TABLE $tableName (');
      final colDefs = <String>[];

      for (final col in table.columns) {
        var def = '    "${col.name}" ${col.dataType}';
        if (col.lengthOrPrecision != null && col.lengthOrPrecision!.isNotEmpty) {
          def += '(${col.lengthOrPrecision})';
        }
        if (col.isNotNull) {
          def += ' NOT NULL';
        }
        if (col.isUnique) {
          def += ' UNIQUE';
        }
        // UUID primary keys get gen_random_uuid() as default
        if (col.dataType.toUpperCase() == 'UUID' && col.isPrimaryKey) {
          def += ' DEFAULT gen_random_uuid()';
        } else if (col.defaultValue != null && col.defaultValue!.isNotEmpty) {
          def += ' DEFAULT ${col.defaultValue}';
        }
        colDefs.add(def);
      }

      final pks = table.primaryKeys;
      if (pks.isNotEmpty) {
        final pkCols = pks.map((c) => '"${c.name}"').join(', ');
        colDefs.add('    CONSTRAINT "pk_${table.name}" PRIMARY KEY ($pkCols)');
      }

      buffer.writeln(colDefs.join(',\n'));
      buffer.writeln(');');
      buffer.writeln();
    }

    // Foreign Keys / Relacionamentos
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
        orElse: () => const ColumnModel(id: '', name: 'id', dataType: 'INT'),
      );
      final fkCol = fkTable.columns.firstWhere(
        (c) => c.id == rel.targetColumnId,
        orElse: () => const ColumnModel(id: '', name: 'id', dataType: 'INT'),
      );

      // Garantir que a coluna referenciada tenha UNIQUE ou PRIMARY KEY
      if (!refCol.isPrimaryKey && !refCol.isUnique) {
        buffer.writeln('-- Adicionar UNIQUE na coluna referenciada para suportar FK');
        buffer.writeln('ALTER TABLE "${refTable.name}"');
        buffer.writeln('    ADD CONSTRAINT "uq_${refTable.name}_${refCol.name}"');
        buffer.writeln('    UNIQUE ("${refCol.name}");');
        buffer.writeln();
      }

      final fkName = rel.name ?? 'fk_${fkTable.name}_${refTable.name}';
      buffer.writeln('ALTER TABLE "${fkTable.name}"');
      buffer.writeln('    ADD CONSTRAINT "$fkName"');
      buffer.writeln('    FOREIGN KEY ("${fkCol.name}")');
      buffer.writeln('    REFERENCES "${refTable.name}" ("${refCol.name}")');
      buffer.writeln('    ON DELETE ${rel.onDelete.sqlKeyword}');
      buffer.writeln('    ON UPDATE ${rel.onUpdate.sqlKeyword};');
      buffer.writeln();
    }

    return buffer.toString();
  }
}
