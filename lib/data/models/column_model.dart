class ColumnModel {
  final String id;
  final String name;
  final String dataType;
  final String? lengthOrPrecision;
  final bool isPrimaryKey;
  final bool isForeignKey;
  final bool isNotNull;
  final bool isUnique;
  final bool isAutoIncrement;
  final String? defaultValue;
  final String? comment;

  const ColumnModel({
    required this.id,
    required this.name,
    required this.dataType,
    this.lengthOrPrecision,
    this.isPrimaryKey = false,
    this.isForeignKey = false,
    this.isNotNull = false,
    this.isUnique = false,
    this.isAutoIncrement = false,
    this.defaultValue,
    this.comment,
  });

  ColumnModel copyWith({
    String? id,
    String? name,
    String? dataType,
    String? lengthOrPrecision,
    bool? isPrimaryKey,
    bool? isForeignKey,
    bool? isNotNull,
    bool? isUnique,
    bool? isAutoIncrement,
    String? defaultValue,
    String? comment,
  }) {
    return ColumnModel(
      id: id ?? this.id,
      name: name ?? this.name,
      dataType: dataType ?? this.dataType,
      lengthOrPrecision: lengthOrPrecision ?? this.lengthOrPrecision,
      isPrimaryKey: isPrimaryKey ?? this.isPrimaryKey,
      isForeignKey: isForeignKey ?? this.isForeignKey,
      isNotNull: isNotNull ?? this.isNotNull,
      isUnique: isUnique ?? this.isUnique,
      isAutoIncrement: isAutoIncrement ?? this.isAutoIncrement,
      defaultValue: defaultValue ?? this.defaultValue,
      comment: comment ?? this.comment,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dataType': dataType,
      'lengthOrPrecision': lengthOrPrecision,
      'isPrimaryKey': isPrimaryKey,
      'isForeignKey': isForeignKey,
      'isNotNull': isNotNull,
      'isUnique': isUnique,
      'isAutoIncrement': isAutoIncrement,
      'defaultValue': defaultValue,
      'comment': comment,
    };
  }

  factory ColumnModel.fromJson(Map<String, dynamic> json) {
    return ColumnModel(
      id: json['id'] as String,
      name: json['name'] as String,
      dataType: json['dataType'] as String,
      lengthOrPrecision: json['lengthOrPrecision'] as String?,
      isPrimaryKey: json['isPrimaryKey'] as bool? ?? false,
      isForeignKey: json['isForeignKey'] as bool? ?? false,
      isNotNull: json['isNotNull'] as bool? ?? false,
      isUnique: json['isUnique'] as bool? ?? false,
      isAutoIncrement: json['isAutoIncrement'] as bool? ?? false,
      defaultValue: json['defaultValue'] as String?,
      comment: json['comment'] as String?,
    );
  }
}
