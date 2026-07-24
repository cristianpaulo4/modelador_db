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
          dataType: 'INT4',
          isPrimaryKey: true,
          isNotNull: true,
          isAutoIncrement: true,
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
          dataType: 'INT4',
          isPrimaryKey: true,
          isNotNull: true,
          isAutoIncrement: true,
        ),
        ColumnModel(
          id: orderUserIdColId,
          name: 'user_id',
          dataType: 'INT4',
          isForeignKey: true,
          isNotNull: true,
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
          dataType: state.activeDialect.availableDataTypes.first,
          isPrimaryKey: true,
          isNotNull: true,
          isAutoIncrement: true,
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
      updateTable(sourceTable.copyWith(columns: updatedCols), saveToHistory: false);
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

    updateTable(sourceTable.copyWith(columns: updatedCols), saveToHistory: false);

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
    state = state.copyWith(
      relationships: state.relationships.where((r) => r.id != relId).toList(),
      clearSelectedRelationship: state.selectedRelationshipId == relId,
    );
  }

  void setDialect(SqlDialect dialect) {
    state = state.copyWith(activeDialect: dialect);
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
          .where((r) => !ids.contains(r.sourceTableId) && !ids.contains(r.targetTableId))
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
    List<RelationshipModel> relationships,
  ) {
    _saveToUndoStack();
    state = state.copyWith(
      tables: tables,
      relationships: relationships,
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
