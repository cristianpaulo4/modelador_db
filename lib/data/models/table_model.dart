import 'dart:ui';
import 'column_model.dart';

class TableModel {
  final String id;
  final String name;
  final String schema;
  final Offset position;
  final List<ColumnModel> columns;
  final String? colorHex;

  const TableModel({
    required this.id,
    required this.name,
    this.schema = 'public',
    required this.position,
    required this.columns,
    this.colorHex,
  });

  TableModel copyWith({
    String? id,
    String? name,
    String? schema,
    Offset? position,
    List<ColumnModel>? columns,
    String? colorHex,
  }) {
    return TableModel(
      id: id ?? this.id,
      name: name ?? this.name,
      schema: schema ?? this.schema,
      position: position ?? this.position,
      columns: columns ?? this.columns,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  /// Retorna as colunas que são Chaves Primárias.
  List<ColumnModel> get primaryKeys => columns.where((c) => c.isPrimaryKey).toList();

  /// Retorna as colunas que são Chaves Estrangeiras.
  List<ColumnModel> get foreignKeys => columns.where((c) => c.isForeignKey).toList();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'schema': schema,
      'x': position.dx,
      'y': position.dy,
      'columns': columns.map((c) => c.toJson()).toList(),
      'colorHex': colorHex,
    };
  }

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      id: json['id'] as String,
      name: json['name'] as String,
      schema: json['schema'] as String? ?? 'public',
      position: Offset(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      ),
      columns: (json['columns'] as List<dynamic>)
          .map((e) => ColumnModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      colorHex: json['colorHex'] as String?,
    );
  }
}
