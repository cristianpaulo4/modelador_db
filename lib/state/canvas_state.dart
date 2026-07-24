import 'dart:ui';

import '../data/models/table_model.dart';
import '../data/models/relationship_model.dart';
import '../generators/sql_dialect.dart';

class CanvasState {
  final List<TableModel> tables;
  final List<RelationshipModel> relationships;
  final String? selectedTableId;
  final Set<String> selectedTableIds;
  final String? selectedRelationshipId;
  final SqlDialect activeDialect;
  final bool isConnectingMode;
  final String? connectionSourceTableId;
  final double zoomLevel;
  final Offset viewportCenter;

  const CanvasState({
    required this.tables,
    required this.relationships,
    this.selectedTableId,
    this.selectedTableIds = const {},
    this.selectedRelationshipId,
    this.activeDialect = SqlDialect.postgres,
    this.isConnectingMode = false,
    this.connectionSourceTableId,
    this.zoomLevel = 1.0,
    this.viewportCenter = const Offset(2000, 2000),
  });

  CanvasState copyWith({
    List<TableModel>? tables,
    List<RelationshipModel>? relationships,
    String? selectedTableId,
    bool clearSelectedTable = false,
    Set<String>? selectedTableIds,
    bool clearSelectedTables = false,
    String? selectedRelationshipId,
    bool clearSelectedRelationship = false,
    SqlDialect? activeDialect,
    bool? isConnectingMode,
    String? connectionSourceTableId,
    bool clearConnectionSource = false,
    double? zoomLevel,
    Offset? viewportCenter,
  }) {
    return CanvasState(
      tables: tables ?? this.tables,
      relationships: relationships ?? this.relationships,
      selectedTableId: clearSelectedTable ? null : (selectedTableId ?? this.selectedTableId),
      selectedTableIds: clearSelectedTables ? {} : (selectedTableIds ?? this.selectedTableIds),
      selectedRelationshipId: clearSelectedRelationship ? null : (selectedRelationshipId ?? this.selectedRelationshipId),
      activeDialect: activeDialect ?? this.activeDialect,
      isConnectingMode: isConnectingMode ?? this.isConnectingMode,
      connectionSourceTableId: clearConnectionSource ? null : (connectionSourceTableId ?? this.connectionSourceTableId),
      zoomLevel: zoomLevel ?? this.zoomLevel,
      viewportCenter: viewportCenter ?? this.viewportCenter,
    );
  }

  TableModel? get selectedTable {
    if (selectedTableId == null) return null;
    try {
      return tables.firstWhere((t) => t.id == selectedTableId);
    } catch (_) {
      return null;
    }
  }

  RelationshipModel? get selectedRelationship {
    if (selectedRelationshipId == null) return null;
    try {
      return relationships.firstWhere((r) => r.id == selectedRelationshipId);
    } catch (_) {
      return null;
    }
  }
}
