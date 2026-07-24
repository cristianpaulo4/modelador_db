enum CardinalityType {
  oneToOne,
  oneToMany,
  manyToOne,
  manyToMany;

  String get label {
    switch (this) {
      case CardinalityType.oneToOne:
        return '1 : 1';
      case CardinalityType.oneToMany:
        return '1 : N';
      case CardinalityType.manyToOne:
        return 'N : 1';
      case CardinalityType.manyToMany:
        return 'N : M';
    }
  }
}

enum ReferentialAction {
  noAction,
  cascade,
  setNull,
  restrict;

  String get sqlKeyword {
    switch (this) {
      case ReferentialAction.noAction:
        return 'NO ACTION';
      case ReferentialAction.cascade:
        return 'CASCADE';
      case ReferentialAction.setNull:
        return 'SET NULL';
      case ReferentialAction.restrict:
        return 'RESTRICT';
    }
  }
}

class RelationshipModel {
  final String id;
  final String sourceTableId;
  final String targetTableId;
  final String sourceColumnId;
  final String targetColumnId;
  final CardinalityType cardinality;
  final ReferentialAction onDelete;
  final ReferentialAction onUpdate;
  final String? name;

  const RelationshipModel({
    required this.id,
    required this.sourceTableId,
    required this.targetTableId,
    required this.sourceColumnId,
    required this.targetColumnId,
    this.cardinality = CardinalityType.oneToMany,
    this.onDelete = ReferentialAction.noAction,
    this.onUpdate = ReferentialAction.noAction,
    this.name,
  });

  RelationshipModel copyWith({
    String? id,
    String? sourceTableId,
    String? targetTableId,
    String? sourceColumnId,
    String? targetColumnId,
    CardinalityType? cardinality,
    ReferentialAction? onDelete,
    ReferentialAction? onUpdate,
    String? name,
  }) {
    return RelationshipModel(
      id: id ?? this.id,
      sourceTableId: sourceTableId ?? this.sourceTableId,
      targetTableId: targetTableId ?? this.targetTableId,
      sourceColumnId: sourceColumnId ?? this.sourceColumnId,
      targetColumnId: targetColumnId ?? this.targetColumnId,
      cardinality: cardinality ?? this.cardinality,
      onDelete: onDelete ?? this.onDelete,
      onUpdate: onUpdate ?? this.onUpdate,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sourceTableId': sourceTableId,
      'targetTableId': targetTableId,
      'sourceColumnId': sourceColumnId,
      'targetColumnId': targetColumnId,
      'cardinality': cardinality.name,
      'onDelete': onDelete.name,
      'onUpdate': onUpdate.name,
      'name': name,
    };
  }

  factory RelationshipModel.fromJson(Map<String, dynamic> json) {
    return RelationshipModel(
      id: json['id'] as String,
      sourceTableId: json['sourceTableId'] as String,
      targetTableId: json['targetTableId'] as String,
      sourceColumnId: json['sourceColumnId'] as String,
      targetColumnId: json['targetColumnId'] as String,
      cardinality: CardinalityType.values.firstWhere(
        (e) => e.name == json['cardinality'],
        orElse: () => CardinalityType.oneToMany,
      ),
      onDelete: ReferentialAction.values.firstWhere(
        (e) => e.name == json['onDelete'],
        orElse: () => ReferentialAction.noAction,
      ),
      onUpdate: ReferentialAction.values.firstWhere(
        (e) => e.name == json['onUpdate'],
        orElse: () => ReferentialAction.noAction,
      ),
      name: json['name'] as String?,
    );
  }
}
