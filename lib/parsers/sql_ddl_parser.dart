import 'dart:ui';
import 'package:uuid/uuid.dart';

import '../data/models/column_model.dart';
import '../data/models/relationship_model.dart';
import '../data/models/table_model.dart';

final _uuid = const Uuid();

class SqlDdlParseResult {
  final List<TableModel> tables;
  final List<RelationshipModel> relationships;

  const SqlDdlParseResult({
    required this.tables,
    required this.relationships,
  });
}

class SqlDdlParser {
  /// Converte um script SQL DDL contendo instruções CREATE TABLE e ALTER TABLE em uma estrutura gráfica de tabelas e relacionamentos.
  static SqlDdlParseResult parseSqlScript(String sqlContent) {
    final List<TableModel> tables = [];
    final List<_PendingRelationship> pendingRels = [];

    // 1. Limpar comentários SQL (-- e /* ... */)
    final cleanedSql = _removeSqlComments(sqlContent);

    // 2. Separar por instruções (delimitadas por ponto e vírgula)
    final statements = cleanedSql.split(';');

    final Map<String, TableModel> tableMapByName = {};
    final Map<String, Map<String, String>> colIdMapByTableAndColName = {};

    int tableGridIndex = 0;

    for (var rawStmt in statements) {
      final stmt = rawStmt.trim();
      if (stmt.isEmpty) continue;

      final upperStmt = stmt.toUpperCase();

      if (upperStmt.contains('CREATE TABLE')) {
        final parsedTable = _parseCreateTable(stmt, tableGridIndex);
        if (parsedTable != null) {
          tables.add(parsedTable.table);
          tableMapByName[parsedTable.table.name.toLowerCase()] = parsedTable.table;

          final colMap = <String, String>{};
          for (final col in parsedTable.table.columns) {
            colMap[col.name.toLowerCase()] = col.id;
          }
          colIdMapByTableAndColName[parsedTable.table.name.toLowerCase()] = colMap;

          pendingRels.addAll(parsedTable.pendingRelationships);
          tableGridIndex++;
        }
      } else if (upperStmt.contains('ALTER TABLE')) {
        final alterRels = _parseAlterTable(stmt);
        pendingRels.addAll(alterRels);
      }
    }

    // 3. Resolver relacionamentos pendentes para mapear nomes de tabela/coluna em IDs reais
    final List<RelationshipModel> resolvedRels = [];
    final Set<String> createdRelKeys = {};

    for (final pending in pendingRels) {
      final rel = _resolvePendingRelationship(
        pending,
        tableMapByName,
        colIdMapByTableAndColName,
      );

      if (rel != null) {
        final relKey = '${rel.sourceTableId}_${rel.sourceColumnId}_${rel.targetTableId}_${rel.targetColumnId}';
        if (!createdRelKeys.contains(relKey)) {
          createdRelKeys.add(relKey);
          resolvedRels.add(rel);
        }
      }
    }

    // 4. Marcar colunas de origem como isForeignKey: true
    final List<TableModel> finalTables = tables.map((t) {
      final sourceRelsForTable = resolvedRels.where((r) => r.sourceTableId == t.id).toList();
      if (sourceRelsForTable.isEmpty) return t;

      final fkColIds = sourceRelsForTable.map((r) => r.sourceColumnId).toSet();
      final updatedCols = t.columns.map((c) {
        if (fkColIds.contains(c.id)) {
          return c.copyWith(isForeignKey: true);
        }
        return c;
      }).toList();

      return t.copyWith(columns: updatedCols);
    }).toList();

    return SqlDdlParseResult(
      tables: finalTables,
      relationships: resolvedRels,
    );
  }

  static String _removeSqlComments(String sql) {
    var result = sql.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
    result = result.replaceAll(RegExp(r'--.*'), '');
    return result;
  }

  static _ParsedTableResult? _parseCreateTable(String statement, int gridIndex) {
    final createRegex = RegExp(
      r'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:([a-zA-Z0-9_"`\[\]]+)\.)?["`\[]?([a-zA-Z0-9_]+)["`\]]?\s*\(([\s\S]+)\)',
      caseSensitive: false,
    );

    final match = createRegex.firstMatch(statement);
    if (match == null) return null;

    final schemaName = _cleanIdentifier(match.group(1) ?? 'public');
    final tableName = _cleanIdentifier(match.group(2)!);
    final bodyContent = match.group(3)!;

    final tableId = _uuid.v4();
    final List<ColumnModel> columns = [];
    final List<_PendingRelationship> pendingRels = [];
    final List<String> primaryKeyColumnNames = [];

    final items = _splitBodyItems(bodyContent);

    for (var item in items) {
      final trimmedItem = item.trim();
      if (trimmedItem.isEmpty) continue;

      final upperItem = trimmedItem.toUpperCase();

      // Restrição de Tabela: PRIMARY KEY (col1, col2)
      if (upperItem.startsWith('PRIMARY KEY') || upperItem.startsWith('CONSTRAINT') && upperItem.contains('PRIMARY KEY')) {
        final pkMatch = RegExp(r'PRIMARY\s+KEY\s*\(([^)]+)\)', caseSensitive: false).firstMatch(trimmedItem);
        if (pkMatch != null) {
          final pkCols = pkMatch.group(1)!.split(',').map((e) => _cleanIdentifier(e)).toList();
          primaryKeyColumnNames.addAll(pkCols);
        }
        continue;
      }

      // Restrição de Tabela: FOREIGN KEY (col) REFERENCES target_table (target_col)
      if (upperItem.contains('FOREIGN KEY') && upperItem.contains('REFERENCES')) {
        final fkMatches = RegExp(
          r'(?:CONSTRAINT\s+["`\[]?(\w+)["`\]]?\s+)?FOREIGN\s+KEY\s*\(([^)]+)\)\s+REFERENCES\s+(?:["`\[]?(\w+)["`\]]?\.)?["`\[]?(\w+)["`\]]?\s*(?:\(([^)]+)\))?([\s\S]*)',
          caseSensitive: false,
        ).allMatches(trimmedItem);

        for (final fkMatch in fkMatches) {
          final srcCols = fkMatch.group(2)!.split(',').map((e) => _cleanIdentifier(e)).toList();
          final targetTable = _cleanIdentifier(fkMatch.group(4)!);
          final targetCols = (fkMatch.group(5) ?? 'id').split(',').map((e) => _cleanIdentifier(e)).toList();
          final restText = (fkMatch.group(6) ?? '').toUpperCase();

          final onDelete = _parseReferentialAction(restText, 'ON DELETE');
          final onUpdate = _parseReferentialAction(restText, 'ON UPDATE');

          for (int i = 0; i < srcCols.length; i++) {
            final srcCol = srcCols[i];
            final targetCol = i < targetCols.length ? targetCols[i] : targetCols.first;

            pendingRels.add(_PendingRelationship(
              sourceTableName: tableName,
              sourceColumnName: srcCol,
              targetTableName: targetTable,
              targetColumnName: targetCol,
              onDelete: onDelete,
              onUpdate: onUpdate,
            ));
          }
        }
        continue;
      }

      // Definição de Coluna (Pode conter REFERENCES inline)
      if (!_isTableConstraint(upperItem)) {
        final parsedCol = _parseColumnDefinition(trimmedItem, tableName);
        if (parsedCol != null) {
          columns.add(parsedCol.column);
          if (parsedCol.pendingRelationship != null) {
            pendingRels.add(parsedCol.pendingRelationship!);
          }
        }
      }
    }

    final finalColumns = columns.map((c) {
      if (primaryKeyColumnNames.contains(c.name.toLowerCase())) {
        return c.copyWith(isPrimaryKey: true, isNotNull: true);
      }
      return c;
    }).toList();

    const colsPerRow = 3;
    final row = gridIndex ~/ colsPerRow;
    final colPos = gridIndex % colsPerRow;
    final posX = (100.0 + (colPos * 340.0)).clamp(0.0, 3740.0);
    final posY = (120.0 + (row * 300.0)).clamp(0.0, 3600.0);
    final position = Offset(posX, posY);

    return _ParsedTableResult(
      table: TableModel(
        id: tableId,
        name: tableName,
        schema: schemaName,
        position: position,
        columns: finalColumns,
      ),
      pendingRelationships: pendingRels,
    );
  }

  static _ParsedColumnResult? _parseColumnDefinition(String colLine, String tableName) {
    final colRegex = RegExp(
      r'^["`\[]?([a-zA-Z0-9_]+)["`\]]?\s+([a-zA-Z0-9_]+(?:\s*\([^)]+\))?)([\s\S]*)',
      caseSensitive: false,
    );

    final match = colRegex.firstMatch(colLine);
    if (match == null) return null;

    final colName = match.group(1)!;
    var fullType = match.group(2)!.trim();
    final rest = (match.group(3) ?? '');
    final upperRest = rest.toUpperCase();

    String dataType = fullType.toUpperCase();
    String? lengthOrPrecision;

    final typeLenMatch = RegExp(r'^([a-zA-Z0-9_]+)\s*\(([^)]+)\)$').firstMatch(fullType);
    if (typeLenMatch != null) {
      dataType = typeLenMatch.group(1)!.toUpperCase();
      lengthOrPrecision = typeLenMatch.group(2)!.trim();
    }

    final isPk = upperRest.contains('PRIMARY KEY');
    final isFk = upperRest.contains('REFERENCES');
    final isNotNull = upperRest.contains('NOT NULL') || isPk;
    final isUnique = upperRest.contains('UNIQUE');
    final isAutoIncrement = upperRest.contains('AUTO_INCREMENT') ||
        upperRest.contains('SERIAL') ||
        upperRest.contains('IDENTITY') ||
        dataType.contains('SERIAL');

    String? defaultValue;
    final defaultMatch = RegExp(r'DEFAULT\s+([^\s,]+)', caseSensitive: false).firstMatch(upperRest);
    if (defaultMatch != null) {
      defaultValue = defaultMatch.group(1);
    }

    _PendingRelationship? inlineRel;

    if (isFk) {
      final inlineFkMatch = RegExp(
        r'REFERENCES\s+(?:["`\[]?(\w+)["`\]]?\.)?["`\[]?(\w+)["`\]]?\s*(?:\(([^)]+)\))?',
        caseSensitive: false,
      ).firstMatch(rest);

      if (inlineFkMatch != null) {
        final targetTableName = _cleanIdentifier(inlineFkMatch.group(2)!);
        final targetColName = _cleanIdentifier(inlineFkMatch.group(3) ?? 'id');

        final onDelete = _parseReferentialAction(upperRest, 'ON DELETE');
        final onUpdate = _parseReferentialAction(upperRest, 'ON UPDATE');

        inlineRel = _PendingRelationship(
          sourceTableName: tableName,
          sourceColumnName: colName,
          targetTableName: targetTableName,
          targetColumnName: targetColName,
          onDelete: onDelete,
          onUpdate: onUpdate,
        );
      }
    }

    return _ParsedColumnResult(
      column: ColumnModel(
        id: _uuid.v4(),
        name: colName,
        dataType: dataType,
        lengthOrPrecision: lengthOrPrecision,
        isPrimaryKey: isPk,
        isForeignKey: isFk,
        isNotNull: isNotNull,
        isUnique: isUnique,
        isAutoIncrement: isAutoIncrement,
        defaultValue: defaultValue,
      ),
      pendingRelationship: inlineRel,
    );
  }

  static List<_PendingRelationship> _parseAlterTable(String statement) {
    final List<_PendingRelationship> rels = [];

    final alterRegex = RegExp(
      r'ALTER\s+TABLE\s+(?:ONLY\s+)?(?:["`\[]?(\w+)["`\]]?\.)?["`\[]?(\w+)["`\]]?[\s\S]*?FOREIGN\s+KEY\s*\(([^)]+)\)\s+REFERENCES\s+(?:["`\[]?(\w+)["`\]]?\.)?["`\[]?(\w+)["`\]]?\s*\(([^)]+)\)([\s\S]*)',
      caseSensitive: false,
    );

    final match = alterRegex.firstMatch(statement);
    if (match == null) return rels;

    final sourceTableName = _cleanIdentifier(match.group(2)!);
    final srcCols = match.group(3)!.split(',').map((e) => _cleanIdentifier(e)).toList();
    final targetTableName = _cleanIdentifier(match.group(5)!);
    final targetCols = match.group(6)!.split(',').map((e) => _cleanIdentifier(e)).toList();
    final restText = (match.group(7) ?? '').toUpperCase();

    final onDelete = _parseReferentialAction(restText, 'ON DELETE');
    final onUpdate = _parseReferentialAction(restText, 'ON UPDATE');

    for (int i = 0; i < srcCols.length; i++) {
      final srcCol = srcCols[i];
      final targetCol = i < targetCols.length ? targetCols[i] : targetCols.first;

      rels.add(_PendingRelationship(
        sourceTableName: sourceTableName,
        sourceColumnName: srcCol,
        targetTableName: targetTableName,
        targetColumnName: targetCol,
        onDelete: onDelete,
        onUpdate: onUpdate,
      ));
    }

    return rels;
  }

  static RelationshipModel? _resolvePendingRelationship(
    _PendingRelationship pending,
    Map<String, TableModel> tableMapByName,
    Map<String, Map<String, String>> colIdMapByTableAndColName,
  ) {
    final sourceTableName = pending.sourceTableName.toLowerCase();
    final targetTableName = pending.targetTableName.toLowerCase();

    final sourceTable = tableMapByName[sourceTableName];
    final targetTable = tableMapByName[targetTableName];

    if (sourceTable == null || targetTable == null) return null;

    final sourceColName = pending.sourceColumnName.toLowerCase();
    var targetColName = pending.targetColumnName.toLowerCase();

    final sourceColId = colIdMapByTableAndColName[sourceTableName]?[sourceColName];
    var targetColId = colIdMapByTableAndColName[targetTableName]?[targetColName];

    // Se o nome da coluna de destino não bater exatamente (ex: 'id'), tenta achar a PK da tabela de destino
    if (targetColId == null) {
      final pkCol = targetTable.primaryKeys.isNotEmpty ? targetTable.primaryKeys.first : targetTable.columns.firstOrNull;
      if (pkCol != null) {
        targetColId = pkCol.id;
      }
    }

    if (sourceColId == null || targetColId == null) return null;

    return RelationshipModel(
      id: _uuid.v4(),
      sourceTableId: sourceTable.id,
      targetTableId: targetTable.id,
      sourceColumnId: sourceColId,
      targetColumnId: targetColId,
      cardinality: CardinalityType.oneToMany,
      onDelete: pending.onDelete,
      onUpdate: pending.onUpdate,
      name: 'fk_${sourceTableName}_$targetTableName',
    );
  }

  static ReferentialAction _parseReferentialAction(String text, String prefix) {
    final idx = text.indexOf(prefix);
    if (idx == -1) return ReferentialAction.noAction;

    final sub = text.substring(idx + prefix.length).trim();
    if (sub.startsWith('CASCADE')) return ReferentialAction.cascade;
    if (sub.startsWith('SET NULL')) return ReferentialAction.setNull;
    if (sub.startsWith('RESTRICT')) return ReferentialAction.restrict;
    return ReferentialAction.noAction;
  }

  static List<String> _splitBodyItems(String content) {
    final List<String> items = [];
    int parenDepth = 0;
    final sb = StringBuffer();

    for (int i = 0; i < content.length; i++) {
      final char = content[i];
      if (char == '(') {
        parenDepth++;
        sb.write(char);
      } else if (char == ')') {
        parenDepth--;
        sb.write(char);
      } else if (char == ',' && parenDepth == 0) {
        items.add(sb.toString());
        sb.clear();
      } else {
        sb.write(char);
      }
    }
    if (sb.isNotEmpty) {
      items.add(sb.toString());
    }

    return items;
  }

  static bool _isTableConstraint(String upperItem) {
    return upperItem.startsWith('CONSTRAINT') ||
        upperItem.startsWith('PRIMARY KEY') ||
        upperItem.startsWith('FOREIGN KEY') ||
        upperItem.startsWith('UNIQUE KEY') ||
        upperItem.startsWith('KEY ');
  }

  static String _cleanIdentifier(String id) {
    return id.replaceAll(RegExp(r'["`\[\]\s]'), '').toLowerCase();
  }
}

class _PendingRelationship {
  final String sourceTableName;
  final String sourceColumnName;
  final String targetTableName;
  final String targetColumnName;
  final ReferentialAction onDelete;
  final ReferentialAction onUpdate;

  const _PendingRelationship({
    required this.sourceTableName,
    required this.sourceColumnName,
    required this.targetTableName,
    required this.targetColumnName,
    this.onDelete = ReferentialAction.noAction,
    this.onUpdate = ReferentialAction.noAction,
  });
}

class _ParsedTableResult {
  final TableModel table;
  final List<_PendingRelationship> pendingRelationships;

  const _ParsedTableResult({
    required this.table,
    required this.pendingRelationships,
  });
}

class _ParsedColumnResult {
  final ColumnModel column;
  final _PendingRelationship? pendingRelationship;

  const _ParsedColumnResult({
    required this.column,
    this.pendingRelationship,
  });
}
