import '../data/models/table_model.dart';
import '../data/models/relationship_model.dart';
import '../generators/sql_dialect.dart';

class CanvasState {
  final List<TableModel> tables;
  final List<RelationshipModel> relationships;
  final String? selectedTableId;
  final String? selectedRelationshipId;
  final SqlDialect activeDialect;
  final bool isConnectingMode;
  final String? connectionSourceTableId;
  final double zoomLevel;

  const CanvasState({
    required this.tables,
    required this.relationships,
    this.selectedTableId,
    this.selectedRelationshipId,
    this.activeDialect = SqlDialect.postgres,
    this.isConnectingMode = false,
    this.connectionSourceTableId,
    this.zoomLevel = 1.0,
  });

  CanvasState copyWith({
    List<TableModel>? tables,
    List<RelationshipModel>? relationships,
    String? selectedTableId,
    bool clearSelectedTable = false,
    String? selectedRelationshipId,
    bool clearSelectedRelationship = false,
    SqlDialect? activeDialect,
    bool? isConnectingMode,
    String? connectionSourceTableId,
    bool clearConnectionSource = false,
    double? zoomLevel,
  }) {
    return CanvasState(
      tables: tables ?? this.tables,
      relationships: relationships ?? this.relationships,
      selectedTableId: clearSelectedTable ? null : (selectedTableId ?? this.selectedTableId),
      selectedRelationshipId: clearSelectedRelationship ? null : (selectedRelationshipId ?? this.selectedRelationshipId),
      activeDialect: activeDialect ?? this.activeDialect,
      isConnectingMode: isConnectingMode ?? this.isConnectingMode,
      connectionSourceTableId: clearConnectionSource ? null : (connectionSourceTableId ?? this.connectionSourceTableId),
      zoomLevel: zoomLevel ?? this.zoomLevel,
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
