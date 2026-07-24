import '../../generators/sql_dialect.dart';
import 'relationship_model.dart';
import 'table_model.dart';

class ProjectSchemaModel {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SqlDialect activeDialect;
  final List<TableModel> tables;
  final List<RelationshipModel> relationships;

  const ProjectSchemaModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.activeDialect = SqlDialect.postgres,
    this.tables = const [],
    this.relationships = const [],
  });

  ProjectSchemaModel copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    SqlDialect? activeDialect,
    List<TableModel>? tables,
    List<RelationshipModel>? relationships,
  }) {
    return ProjectSchemaModel(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      activeDialect: activeDialect ?? this.activeDialect,
      tables: tables ?? this.tables,
      relationships: relationships ?? this.relationships,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'activeDialect': activeDialect.code,
      'tables': tables.map((t) => t.toJson()).toList(),
      'relationships': relationships.map((r) => r.toJson()).toList(),
    };
  }

  factory ProjectSchemaModel.fromJson(Map<String, dynamic> json) {
    final dialectCode = json['activeDialect'] as String? ?? 'postgresql';
    final dialect = SqlDialect.values.firstWhere(
      (d) => d.code == dialectCode,
      orElse: () => SqlDialect.postgres,
    );

    return ProjectSchemaModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Esquema sem nome',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      activeDialect: dialect,
      tables: (json['tables'] as List<dynamic>?)
              ?.map((t) => TableModel.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      relationships: (json['relationships'] as List<dynamic>?)
              ?.map((r) => RelationshipModel.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
