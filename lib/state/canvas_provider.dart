import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/models/column_model.dart';
import '../data/models/relationship_model.dart';
import '../data/models/table_model.dart';
import '../generators/sql_dialect.dart';
import 'canvas_state.dart';

final _uuid = const Uuid();

class CanvasNotifier extends StateNotifier<CanvasState> {
  CanvasNotifier() : super(const CanvasState(tables: [], relationships: []));

  // Undo/Redo history
  final List<CanvasState> _undoStack = [];
  final List<CanvasState> _redoStack = [];
  static const int _maxHistorySize = 50;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void _saveToUndoStack() {
    _undoStack.add(state);
    if (_undoStack.length > _maxHistorySize) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(state);
    state = _undoStack.removeLast();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(state);
    state = _redoStack.removeLast();
  }

  // Clipboard para Copy/Paste/Cut
  List<TableModel> _clipboardTables = [];
  List<RelationshipModel> _clipboardRelationships = [];
  bool _isCutOperation = false;

  bool get hasClipboard => _clipboardTables.isNotEmpty;

  /// Copia as tabelas selecionadas para o clipboard
  void copySelectedTables() {
    // Verificar tanto selectedTableId (seleção única) quanto selectedTableIds (seleção múltipla)
    final selectedIds = <String>{};
    if (state.selectedTableId != null) {
      selectedIds.add(state.selectedTableId!);
    }
    selectedIds.addAll(state.selectedTableIds);

    if (selectedIds.isEmpty) return;

    _clipboardTables = state.tables
        .where((t) => selectedIds.contains(t.id))
        .toList();
    _clipboardRelationships = state.relationships
        .where(
          (r) =>
              selectedIds.contains(r.sourceTableId) &&
              selectedIds.contains(r.targetTableId),
        )
        .toList();
    _isCutOperation = false;
  }

  /// Recorta as tabelas selecionadas (copia + deleta)
  void cutSelectedTables() {
    // Verificar tanto selectedTableId quanto selectedTableIds
    final selectedIds = <String>{};
    if (state.selectedTableId != null) {
      selectedIds.add(state.selectedTableId!);
    }
    selectedIds.addAll(state.selectedTableIds);

    if (selectedIds.isEmpty) return;

    copySelectedTables();
    _isCutOperation = true;

    // Deletar tabelas selecionadas
    _saveToUndoStack();
    state = state.copyWith(
      tables: state.tables.where((t) => !selectedIds.contains(t.id)).toList(),
      relationships: state.relationships
          .where(
            (r) =>
                !selectedIds.contains(r.sourceTableId) &&
                !selectedIds.contains(r.targetTableId),
          )
          .toList(),
      clearSelectedTable: true,
      clearSelectedTables: true,
    );
  }

  /// Cola as tabelas do clipboard no canvas
  void pasteTables({Offset? position}) {
    if (_clipboardTables.isEmpty) return;
    _saveToUndoStack();

    // Criar mapeamento de IDs antigos para novos
    final idMapping = <String, String>{};
    for (final table in _clipboardTables) {
      idMapping[table.id] = _uuid.v4();
    }

    // Calcular offset baseado no centro da viewport ou posição fornecida
    final pastePosition = position ?? state.viewportCenter;

    // Calcular centro das tabelas copiadas
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final table in _clipboardTables) {
      minX = minX < table.position.dx ? minX : table.position.dx;
      minY = minY < table.position.dy ? minY : table.position.dy;
      maxX = maxX > table.position.dx ? maxX : table.position.dx;
      maxY = maxY > table.position.dy ? maxY : table.position.dy;
    }
    final centerOfCopied = Offset((minX + maxX) / 2, (minY + maxY) / 2);

    // Offset para mover as tabelas para a posição de cola
    final offset = pastePosition - centerOfCopied;

    // Criar novas tabelas com IDs novos e posições offsetadas
    final newTables = _clipboardTables.map((table) {
      final newId = idMapping[table.id]!;
      final newPosition = table.position + offset;

      // Mapear colunas (manter IDs para preservar relações internas)
      final newColumns = table.columns.map((col) {
        return col;
      }).toList();

      return table.copyWith(
        id: newId,
        name: '${table.name}_copy',
        position: newPosition,
        columns: newColumns,
      );
    }).toList();

    // Criar novos relacionamentos com IDs de tabelas atualizados
    final newRelationships = _clipboardRelationships.map((rel) {
      final newSourceId = idMapping[rel.sourceTableId] ?? rel.sourceTableId;
      final newTargetId = idMapping[rel.targetTableId] ?? rel.targetTableId;
      return rel.copyWith(
        id: _uuid.v4(),
        sourceTableId: newSourceId,
        targetTableId: newTargetId,
      );
    }).toList();

    // Adicionar ao canvas
    state = state.copyWith(
      tables: [...state.tables, ...newTables],
      relationships: [...state.relationships, ...newRelationships],
      selectedTableIds: newTables.map((t) => t.id).toSet(),
      clearSelectedTable: true,
    );

    // Se era operação de cut, limpar clipboard
    if (_isCutOperation) {
      _clipboardTables = [];
      _clipboardRelationships = [];
      _isCutOperation = false;
    }
  }

  /// Duplica as tabelas selecionadas (atalho mais rápido que copy+paste)
  void duplicateSelectedTables() {
    // Verificar tanto selectedTableId quanto selectedTableIds
    final selectedIds = <String>{};
    if (state.selectedTableId != null) {
      selectedIds.add(state.selectedTableId!);
    }
    selectedIds.addAll(state.selectedTableIds);

    if (selectedIds.isEmpty) return;

    // Copiar seleção atual para clipboard temporário
    final tempClipboard = _clipboardTables;
    final tempRelClipboard = _clipboardRelationships;
    final tempIsCut = _isCutOperation;

    // Copiar sem afetar clipboard principal
    _clipboardTables = state.tables
        .where((t) => selectedIds.contains(t.id))
        .toList();
    _clipboardRelationships = state.relationships
        .where(
          (r) =>
              selectedIds.contains(r.sourceTableId) &&
              selectedIds.contains(r.targetTableId),
        )
        .toList();
    _isCutOperation = false;

    // Colar com offset para não sobrepor
    _saveToUndoStack();

    final idMapping = <String, String>{};
    for (final table in _clipboardTables) {
      idMapping[table.id] = _uuid.v4();
    }

    // Offset de 30px para baixo e direita
    const duplicateOffset = Offset(30, 30);

    final newTables = _clipboardTables.map((table) {
      final newId = idMapping[table.id]!;
      final newPosition = table.position + duplicateOffset;

      return table.copyWith(
        id: newId,
        name: '${table.name}_copy',
        position: newPosition,
      );
    }).toList();

    final newRelationships = _clipboardRelationships.map((rel) {
      final newSourceId = idMapping[rel.sourceTableId] ?? rel.sourceTableId;
      final newTargetId = idMapping[rel.targetTableId] ?? rel.targetTableId;
      return rel.copyWith(
        id: _uuid.v4(),
        sourceTableId: newSourceId,
        targetTableId: newTargetId,
      );
    }).toList();

    state = state.copyWith(
      tables: [...state.tables, ...newTables],
      relationships: [...state.relationships, ...newRelationships],
      selectedTableIds: newTables.map((t) => t.id).toSet(),
      clearSelectedTable: true,
    );

    // Restaurar clipboard original
    _clipboardTables = tempClipboard;
    _clipboardRelationships = tempRelClipboard;
    _isCutOperation = tempIsCut;
  }

  void createSampleData() {
    final userIdColId = _uuid.v4();
    final orderIdColId = _uuid.v4();
    final orderUserIdColId = _uuid.v4();

    final userTableId = _uuid.v4();
    final orderTableId = _uuid.v4();

    final usersTable = TableModel(
      id: userTableId,
      name: 'users',
      schema: 'public',
      position: const Offset(100, 150),
      columns: [
        ColumnModel(
          id: userIdColId,
          name: 'id',
          dataType: state.activeDialect.idDataType,
          isPrimaryKey: true,
          isNotNull: true,
          isAutoIncrement: state.activeDialect.idIsAutoIncrement,
        ),
        const ColumnModel(
          id: 'col_name',
          name: 'name',
          dataType: 'VARCHAR',
          lengthOrPrecision: '100',
          isNotNull: true,
        ),
        const ColumnModel(
          id: 'col_email',
          name: 'email',
          dataType: 'VARCHAR',
          lengthOrPrecision: '255',
          isNotNull: true,
          isUnique: true,
        ),
        const ColumnModel(
          id: 'col_created_at',
          name: 'created_at',
          dataType: 'TIMESTAMP',
          defaultValue: 'CURRENT_TIMESTAMP',
        ),
      ],
    );

    final ordersTable = TableModel(
      id: orderTableId,
      name: 'orders',
      schema: 'public',
      position: const Offset(550, 150),
      columns: [
        ColumnModel(
          id: orderIdColId,
          name: 'id',
          dataType: state.activeDialect.idDataType,
          isPrimaryKey: true,
          isNotNull: true,
          isAutoIncrement: state.activeDialect.idIsAutoIncrement,
        ),
        ColumnModel(
          id: orderUserIdColId,
          name: 'user_id',
          dataType: state.activeDialect.idDataType,
          isForeignKey: true,
          isNotNull: true,
          isAutoIncrement: false,
        ),
        const ColumnModel(
          id: 'col_total',
          name: 'total_amount',
          dataType: 'NUMERIC',
          lengthOrPrecision: '10,2',
          isNotNull: true,
        ),
        const ColumnModel(
          id: 'col_status',
          name: 'status',
          dataType: 'VARCHAR',
          lengthOrPrecision: '20',
          defaultValue: "'PENDING'",
        ),
      ],
    );

    final relId = _uuid.v4();
    final rel = RelationshipModel(
      id: relId,
      sourceTableId: orderTableId,
      targetTableId: userTableId,
      sourceColumnId: orderUserIdColId,
      targetColumnId: userIdColId,
      cardinality: CardinalityType.oneToMany,
      onDelete: ReferentialAction.cascade,
      onUpdate: ReferentialAction.noAction,
      name: 'fk_orders_users',
    );

    state = state.copyWith(
      tables: [usersTable, ordersTable],
      relationships: [rel],
    );
  }

  void updateViewportCenter(Offset center) {
    state = state.copyWith(viewportCenter: center);
  }

  void addTable({Offset? position}) {
    _saveToUndoStack();
    final newId = _uuid.v4();
    final colId = _uuid.v4();
    final createAtId = _uuid.v4();
    final updateAtId = _uuid.v4();

    // Usar posição fornecida ou centro da viewport
    final tablePosition = position ?? state.viewportCenter;

    final newTable = TableModel(
      id: newId,
      name: 'new_table_${state.tables.length + 1}',
      schema: 'public',
      position: tablePosition,
      columns: [
        ColumnModel(
          id: colId,
          name: 'id',
          dataType: state.activeDialect.idDataType,
          isPrimaryKey: true,
          isNotNull: true,
          isAutoIncrement: state.activeDialect.idIsAutoIncrement,
        ),
        ColumnModel(
          id: createAtId,
          name: 'create_at',
          dataType: state.activeDialect.timestampType,
          defaultValue: 'CURRENT_TIMESTAMP',
          isNotNull: true,
        ),
        ColumnModel(
          id: updateAtId,
          name: 'update_at',
          dataType: state.activeDialect.timestampType,
          defaultValue: 'CURRENT_TIMESTAMP',
          isNotNull: true,
        ),
      ],
    );

    state = state.copyWith(
      tables: [...state.tables, newTable],
      selectedTableId: newId,
      clearSelectedRelationship: true,
    );
  }

  void updateTablePosition(String tableId, Offset newPosition) {
    _saveToUndoStack();
    // Garantir que a posição da tabela nunca fique fora dos limites do Canvas (evitando perder o hit-test/seleção)
    final clampedX = newPosition.dx.clamp(0.0, 3740.0);
    final clampedY = newPosition.dy.clamp(0.0, 3600.0);
    final clampedPosition = Offset(clampedX, clampedY);

    state = state.copyWith(
      tables: state.tables.map((t) {
        if (t.id == tableId) {
          return t.copyWith(position: clampedPosition);
        }
        return t;
      }).toList(),
    );
  }

  void updateTable(TableModel updatedTable, {bool saveToHistory = true}) {
    if (saveToHistory) _saveToUndoStack();
    state = state.copyWith(
      tables: state.tables
          .map((t) => t.id == updatedTable.id ? updatedTable : t)
          .toList(),
    );
  }

  void deleteTable(String tableId) {
    _saveToUndoStack();
    state = state.copyWith(
      tables: state.tables.where((t) => t.id != tableId).toList(),
      relationships: state.relationships
          .where(
            (r) => r.sourceTableId != tableId && r.targetTableId != tableId,
          )
          .toList(),
      clearSelectedTable: state.selectedTableId == tableId,
      selectedTableIds: state.selectedTableIds.contains(tableId)
          ? (state.selectedTableIds..remove(tableId))
          : null,
    );
  }

  void addColumn(String tableId) {
    _saveToUndoStack();
    final colId = _uuid.v4();
    final newCol = ColumnModel(
      id: colId,
      name: 'column_${DateTime.now().millisecondsSinceEpoch % 1000}',
      dataType: state.activeDialect.availableDataTypes.first,
    );

    state = state.copyWith(
      tables: state.tables.map((t) {
        if (t.id == tableId) {
          return t.copyWith(columns: [...t.columns, newCol]);
        }
        return t;
      }).toList(),
    );
  }

  void updateColumn(String tableId, ColumnModel updatedColumn) {
    _saveToUndoStack();
    state = state.copyWith(
      tables: state.tables.map((t) {
        if (t.id == tableId) {
          final updatedCols = t.columns
              .map((c) => c.id == updatedColumn.id ? updatedColumn : c)
              .toList();
          return t.copyWith(columns: updatedCols);
        }
        return t;
      }).toList(),
    );
  }

  void deleteColumn(String tableId, String columnId) {
    _saveToUndoStack();
    state = state.copyWith(
      tables: state.tables.map((t) {
        if (t.id == tableId) {
          return t.copyWith(
            columns: t.columns.where((c) => c.id != columnId).toList(),
          );
        }
        return t;
      }).toList(),
      relationships: state.relationships
          .where(
            (r) => r.sourceColumnId != columnId && r.targetColumnId != columnId,
          )
          .toList(),
    );
  }

  void startConnectionMode(String sourceTableId) {
    state = state.copyWith(
      isConnectingMode: true,
      connectionSourceTableId: sourceTableId,
    );
  }

  void cancelConnectionMode() {
    state = state.copyWith(
      isConnectingMode: false,
      clearConnectionSource: true,
    );
  }

  void addRelationship(RelationshipModel newRel) {
    _saveToUndoStack();
    final sourceTable = state.tables.firstWhere(
      (t) => t.id == newRel.sourceTableId,
      orElse: () =>
          TableModel(id: '', name: '', position: Offset.zero, columns: []),
    );
    if (sourceTable.id.isNotEmpty) {
      final updatedCols = sourceTable.columns.map((c) {
        if (c.id == newRel.sourceColumnId) {
          return c.copyWith(isForeignKey: true);
        }
        return c;
      }).toList();
      updateTable(
        sourceTable.copyWith(columns: updatedCols),
        saveToHistory: false,
      );
    }

    state = state.copyWith(
      relationships: [...state.relationships, newRel],
      selectedRelationshipId: newRel.id,
      clearSelectedTable: true,
    );
  }

  void completeConnection({
    required String targetTableId,
    required String sourceColumnId,
    required String targetColumnId,
    CardinalityType cardinality = CardinalityType.oneToMany,
  }) {
    if (state.connectionSourceTableId == null) return;

    final sourceTableId = state.connectionSourceTableId!;
    if (sourceTableId == targetTableId) {
      cancelConnectionMode();
      return;
    }

    _saveToUndoStack();

    final newRel = RelationshipModel(
      id: _uuid.v4(),
      sourceTableId: sourceTableId,
      targetTableId: targetTableId,
      sourceColumnId: sourceColumnId,
      targetColumnId: targetColumnId,
      cardinality: cardinality,
    );

    // Marca a coluna como FK na tabela de origem
    final sourceTable = state.tables.firstWhere((t) => t.id == sourceTableId);
    final updatedCols = sourceTable.columns.map((c) {
      if (c.id == sourceColumnId) {
        return c.copyWith(isForeignKey: true);
      }
      return c;
    }).toList();

    updateTable(
      sourceTable.copyWith(columns: updatedCols),
      saveToHistory: false,
    );

    state = state.copyWith(
      relationships: [...state.relationships, newRel],
      isConnectingMode: false,
      clearConnectionSource: true,
      selectedRelationshipId: newRel.id,
      clearSelectedTable: true,
    );
  }

  void updateRelationship(RelationshipModel updatedRel) {
    _saveToUndoStack();
    state = state.copyWith(
      relationships: state.relationships
          .map((r) => r.id == updatedRel.id ? updatedRel : r)
          .toList(),
    );
  }

  void deleteRelationship(String relId) {
    _saveToUndoStack();

    final rel = state.relationships.where((r) => r.id == relId).firstOrNull;
    String? fkTableId;
    String? fkColumnId;

    if (rel != null) {
      final sourceTable =
          state.tables.where((t) => t.id == rel.sourceTableId).firstOrNull;
      final targetTable =
          state.tables.where((t) => t.id == rel.targetTableId).firstOrNull;
      final sourceCol = sourceTable?.columns
          .where((c) => c.id == rel.sourceColumnId)
          .firstOrNull;
      final targetCol = targetTable?.columns
          .where((c) => c.id == rel.targetColumnId)
          .firstOrNull;

      if (targetCol != null &&
          targetCol.isForeignKey &&
          !targetCol.isPrimaryKey) {
        fkTableId = targetTable!.id;
        fkColumnId = targetCol.id;
      } else if (sourceCol != null &&
          sourceCol.isForeignKey &&
          !sourceCol.isPrimaryKey) {
        fkTableId = sourceTable!.id;
        fkColumnId = sourceCol.id;
      } else if (targetCol != null &&
          !targetCol.isPrimaryKey &&
          sourceCol != null &&
          sourceCol.isPrimaryKey) {
        fkTableId = targetTable!.id;
        fkColumnId = targetCol.id;
      } else if (sourceCol != null &&
          !sourceCol.isPrimaryKey &&
          targetCol != null &&
          targetCol.isPrimaryKey) {
        fkTableId = sourceTable!.id;
        fkColumnId = sourceCol.id;
      } else if (targetCol != null && targetCol.isForeignKey) {
        fkTableId = targetTable!.id;
        fkColumnId = targetCol.id;
      } else if (sourceCol != null && sourceCol.isForeignKey) {
        fkTableId = sourceTable!.id;
        fkColumnId = sourceCol.id;
      }

      if (fkColumnId != null) {
        final isUsedByOtherRel = state.relationships.any(
          (r) =>
              r.id != relId &&
              (r.sourceColumnId == fkColumnId || r.targetColumnId == fkColumnId),
        );
        if (isUsedByOtherRel) {
          fkTableId = null;
          fkColumnId = null;
        }
      }
    }

    final updatedTables = fkTableId != null && fkColumnId != null
        ? state.tables.map((t) {
            if (t.id == fkTableId) {
              return t.copyWith(
                columns: t.columns.where((c) => c.id != fkColumnId).toList(),
              );
            }
            return t;
          }).toList()
        : state.tables;

    state = state.copyWith(
      relationships: state.relationships.where((r) => r.id != relId).toList(),
      tables: updatedTables,
      clearSelectedRelationship: state.selectedRelationshipId == relId,
    );
  }

  void setDialect(SqlDialect dialect) {
    if (state.activeDialect == dialect) return;
    _saveToUndoStack();

    final updatedTables = state.tables.map((table) {
      final updatedColumns = table.columns.map((col) {
        return dialect.mapColumn(col);
      }).toList();
      return table.copyWith(columns: updatedColumns);
    }).toList();

    state = state.copyWith(
      activeDialect: dialect,
      tables: updatedTables,
    );
  }

  void selectTable(String? tableId) {
    state = state.copyWith(
      selectedTableId: tableId,
      clearSelectedTable: tableId == null,
      clearSelectedTables: true,
      clearSelectedRelationship: true,
    );
  }

  void selectMultipleTables(Set<String> ids) {
    state = state.copyWith(
      selectedTableIds: ids,
      clearSelectedTable: true,
      clearSelectedRelationship: true,
    );
  }

  void clearSelection() {
    state = state.copyWith(
      clearSelectedTable: true,
      clearSelectedTables: true,
      clearSelectedRelationship: true,
    );
  }

  void deleteSelectedTables() {
    final ids = state.selectedTableIds;
    if (ids.isEmpty) return;
    _saveToUndoStack();
    state = state.copyWith(
      tables: state.tables.where((t) => !ids.contains(t.id)).toList(),
      relationships: state.relationships
          .where(
            (r) =>
                !ids.contains(r.sourceTableId) &&
                !ids.contains(r.targetTableId),
          )
          .toList(),
      clearSelectedTables: true,
    );
  }

  void updateMultipleTablePositions(Offset delta) {
    final ids = state.selectedTableIds;
    if (ids.isEmpty) return;
    state = state.copyWith(
      tables: state.tables.map((t) {
        if (ids.contains(t.id)) {
          final clampedX = (t.position.dx + delta.dx).clamp(0.0, 3740.0);
          final clampedY = (t.position.dy + delta.dy).clamp(0.0, 3600.0);
          return t.copyWith(position: Offset(clampedX, clampedY));
        }
        return t;
      }).toList(),
    );
  }

  void selectRelationship(String? relId) {
    state = state.copyWith(
      selectedRelationshipId: relId,
      clearSelectedRelationship: relId == null,
      clearSelectedTable: true,
    );
  }

  void clearCanvas() {
    _saveToUndoStack();
    state = state.copyWith(
      tables: [],
      relationships: [],
      clearSelectedTable: true,
      clearSelectedRelationship: true,
      isConnectingMode: false,
      clearConnectionSource: true,
    );
  }

  Map<String, dynamic> exportToJson() {
    return {
      'activeDialect': state.activeDialect.code,
      'tables': state.tables.map((t) => t.toJson()).toList(),
      'relationships': state.relationships.map((r) => r.toJson()).toList(),
    };
  }

  void importDdlResult(
    List<TableModel> tables,
    List<RelationshipModel> relationships, {
    SqlDialect? dialect,
  }) {
    _saveToUndoStack();
    state = state.copyWith(
      tables: tables,
      relationships: relationships,
      activeDialect: dialect ?? state.activeDialect,
      clearSelectedTable: true,
      clearSelectedRelationship: true,
    );
  }

  void importFromJson(Map<String, dynamic> json) {
    _saveToUndoStack();
    final dialectCode = json['activeDialect'] as String? ?? 'postgresql';
    final dialect = SqlDialect.values.firstWhere(
      (d) => d.code == dialectCode,
      orElse: () => SqlDialect.postgres,
    );

    final tablesJson = json['tables'] as List<dynamic>? ?? [];
    final relsJson = json['relationships'] as List<dynamic>? ?? [];

    final tables = tablesJson
        .map((e) => TableModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final rels = relsJson
        .map((e) => RelationshipModel.fromJson(e as Map<String, dynamic>))
        .toList();

    state = state.copyWith(
      activeDialect: dialect,
      tables: tables,
      relationships: rels,
      clearSelectedTable: true,
      clearSelectedRelationship: true,
    );
  }
}

final canvasProvider = StateNotifierProvider<CanvasNotifier, CanvasState>((
  ref,
) {
  return CanvasNotifier();
});
