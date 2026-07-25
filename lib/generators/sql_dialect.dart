import '../data/models/column_model.dart';

enum SqlDialect {
  postgres('PostgreSQL', 'postgresql'),
  mysql('MySQL / MariaDB', 'mysql'),
  sqlite('SQLite', 'sqlite'),
  sqlserver('SQL Server (T-SQL)', 'sqlserver'),
  oracle('Oracle DB', 'oracle');

  final String displayName;
  final String code;

  const SqlDialect(this.displayName, this.code);

  /// Tipo de dado padrão para chave primária / ID no dialeto
  String get idDataType {
    switch (this) {
      case SqlDialect.sqlite:
        return 'INTEGER';
      case SqlDialect.postgres:
        return 'UUID';
      case SqlDialect.mysql:
        return 'VARCHAR(36)';
      case SqlDialect.sqlserver:
        return 'UNIQUEIDENTIFIER';
      case SqlDialect.oracle:
        return 'RAW(16)';
    }
  }

  /// Indica se a chave primária padrão deve usar autoincremento (apenas no SQLite)
  bool get idIsAutoIncrement {
    return this == SqlDialect.sqlite;
  }

  /// Tipo de dado UUID padrão para cada dialeto
  String get uuidType {
    switch (this) {
      case SqlDialect.postgres:
        return 'UUID';
      case SqlDialect.mysql:
        return 'VARCHAR(36)';
      case SqlDialect.sqlite:
        return 'TEXT';
      case SqlDialect.sqlserver:
        return 'UNIQUEIDENTIFIER';
      case SqlDialect.oracle:
        return 'RAW(16)';
    }
  }

  /// Tipo de dado TIMESTAMP padrão para cada dialeto
  String get timestampType {
    switch (this) {
      case SqlDialect.postgres:
      case SqlDialect.mysql:
      case SqlDialect.oracle:
        return 'TIMESTAMP';
      case SqlDialect.sqlite:
        return 'DATETIME';
      case SqlDialect.sqlserver:
        return 'DATETIME2';
    }
  }

  List<String> get availableDataTypes {
    switch (this) {
      case SqlDialect.postgres:
        return [
          'VARCHAR',
          'TEXT',
          'INT4',
          'INT8',
          'SERIAL',
          'BIGSERIAL',
          'BOOLEAN',
          'UUID',
          'JSONB',
          'TIMESTAMP',
          'DATE',
          'TIME',
          'NUMERIC',
          'REAL',
          'DOUBLE PRECISION',
          'BYTEA',
        ];
      case SqlDialect.mysql:
        return [
          'VARCHAR',
          'TEXT',
          'INT',
          'BIGINT',
          'SMALLINT',
          'TINYINT(1)',
          'AUTO_INCREMENT',
          'DATETIME',
          'TIMESTAMP',
          'DATE',
          'DECIMAL',
          'FLOAT',
          'DOUBLE',
          'JSON',
          'BLOB',
        ];
      case SqlDialect.sqlite:
        return [
          'INTEGER',
          'TEXT',
          'REAL',
          'BLOB',
          'NUMERIC',
          'DATETIME',
          'BOOLEAN',
        ];
      case SqlDialect.sqlserver:
        return [
          'VARCHAR',
          'NVARCHAR',
          'TEXT',
          'NTEXT',
          'INT',
          'BIGINT',
          'SMALLINT',
          'TINYINT',
          'BIT',
          'DATETIME2',
          'DATE',
          'DECIMAL',
          'FLOAT',
          'MONEY',
          'VARBINARY',
          'UNIQUEIDENTIFIER',
        ];
      case SqlDialect.oracle:
        return [
          'VARCHAR2',
          'NVARCHAR2',
          'NUMBER',
          'DATE',
          'TIMESTAMP',
          'CLOB',
          'NCLOB',
          'BLOB',
          'RAW',
          'FLOAT',
        ];
    }
  }

  /// Converte um tipo de dado de qualquer dialeto para o equivalente mais próximo neste dialeto.
  String mapDataType(String currentType) {
    final upper = currentType.trim().toUpperCase();

    // 1. Se o tipo exato já é aceito neste dialeto, mantém inalterado
    if (availableDataTypes.contains(upper)) {
      return upper;
    }

    // 2. Verifica se é um tipo com parênteses (ex: VARCHAR(255), DECIMAL(10,2))
    // Excluímos tipos especiais (TINYINT(1), VARCHAR(36), RAW(16)) para que sejam mapeados semantimacamente para BOOLEAN / UUID
    String baseType = upper;
    if (upper.contains('(')) {
      baseType = upper.substring(0, upper.indexOf('(')).trim();
      if (upper != 'TINYINT(1)' &&
          upper != 'VARCHAR(36)' &&
          upper != 'RAW(16)' &&
          availableDataTypes.contains(baseType)) {
        return baseType;
      }
    }

    // 3. Mapeamento por Categorias Semânticas (com prioridade para tipos especiais Booleanos e UUIDs)

    // Categoria: Booleanos
    if (['BOOLEAN', 'BOOL', 'BIT'].contains(baseType) ||
        upper == 'TINYINT(1)') {
      switch (this) {
        case SqlDialect.postgres:
        case SqlDialect.sqlite:
          return 'BOOLEAN';
        case SqlDialect.mysql:
          return 'TINYINT(1)';
        case SqlDialect.sqlserver:
          return 'BIT';
        case SqlDialect.oracle:
          return 'NUMBER';
      }
    }

    // Categoria: Identificadores únicos / UUIDs
    if (['UUID', 'UNIQUEIDENTIFIER', 'GUID'].contains(baseType) ||
        upper == 'VARCHAR(36)' ||
        upper == 'RAW(16)') {
      return uuidType;
    }

    // Categoria: Strings curtas
    if ([
      'VARCHAR',
      'VARCHAR2',
      'NVARCHAR',
      'NVARCHAR2',
      'STRING',
      'CHARACTER VARYING',
      'CHAR',
      'NCHAR',
    ].contains(baseType)) {
      switch (this) {
        case SqlDialect.postgres:
        case SqlDialect.mysql:
        case SqlDialect.sqlserver:
          return 'VARCHAR';
        case SqlDialect.sqlite:
          return 'TEXT';
        case SqlDialect.oracle:
          return 'VARCHAR2';
      }
    }

    // Categoria: Textos longos / CLOBs
    if ([
      'TEXT',
      'NTEXT',
      'CLOB',
      'NCLOB',
      'MEDIUMTEXT',
      'LONGTEXT',
      'TINYTEXT',
    ].contains(baseType)) {
      switch (this) {
        case SqlDialect.postgres:
        case SqlDialect.mysql:
        case SqlDialect.sqlite:
        case SqlDialect.sqlserver:
          return 'TEXT';
        case SqlDialect.oracle:
          return 'CLOB';
      }
    }

    // Categoria: Inteiros padrões (32 bits ou menores)
    if ([
      'INT',
      'INTEGER',
      'INT4',
      'SMALLINT',
      'TINYINT',
      'MEDIUMINT',
      'INT2',
    ].contains(baseType)) {
      switch (this) {
        case SqlDialect.postgres:
          return 'INT4';
        case SqlDialect.mysql:
        case SqlDialect.sqlserver:
          return 'INT';
        case SqlDialect.sqlite:
          return 'INTEGER';
        case SqlDialect.oracle:
          return 'NUMBER';
      }
    }

    // Categoria: Inteiros grandes (64 bits)
    if (['BIGINT', 'INT8'].contains(baseType)) {
      switch (this) {
        case SqlDialect.postgres:
          return 'INT8';
        case SqlDialect.mysql:
        case SqlDialect.sqlserver:
          return 'BIGINT';
        case SqlDialect.sqlite:
          return 'INTEGER';
        case SqlDialect.oracle:
          return 'NUMBER';
      }
    }

    // Categoria: Autoincremento / Seriais
    if ([
      'SERIAL',
      'BIGSERIAL',
      'AUTO_INCREMENT',
      'IDENTITY',
    ].contains(baseType)) {
      switch (this) {
        case SqlDialect.postgres:
          return 'SERIAL';
        case SqlDialect.mysql:
          return 'AUTO_INCREMENT';
        case SqlDialect.sqlite:
          return 'INTEGER';
        case SqlDialect.sqlserver:
          return 'INT';
        case SqlDialect.oracle:
          return 'NUMBER';
      }
    }

    // Categoria: Numéricos exatos / Decimais / Moeda
    if ([
      'DECIMAL',
      'NUMERIC',
      'NUMBER',
      'MONEY',
      'SMALLMONEY',
    ].contains(baseType)) {
      switch (this) {
        case SqlDialect.postgres:
        case SqlDialect.sqlite:
          return 'NUMERIC';
        case SqlDialect.mysql:
        case SqlDialect.sqlserver:
          return 'DECIMAL';
        case SqlDialect.oracle:
          return 'NUMBER';
      }
    }

    // Categoria: Ponto flutuante
    if (['FLOAT', 'REAL', 'DOUBLE', 'DOUBLE PRECISION'].contains(baseType)) {
      switch (this) {
        case SqlDialect.postgres:
          return 'DOUBLE PRECISION';
        case SqlDialect.mysql:
        case SqlDialect.sqlserver:
        case SqlDialect.oracle:
          return 'FLOAT';
        case SqlDialect.sqlite:
          return 'REAL';
      }
    }

    // Categoria: Data e Hora combinados
    if ([
      'TIMESTAMP',
      'DATETIME',
      'DATETIME2',
      'TIMESTAMPTZ',
      'TIMESTAMP WITH TIME ZONE',
    ].contains(baseType)) {
      return timestampType;
    }

    // Categoria: Apenas Data
    if (['DATE'].contains(baseType)) {
      switch (this) {
        case SqlDialect.postgres:
        case SqlDialect.mysql:
        case SqlDialect.sqlserver:
        case SqlDialect.oracle:
          return 'DATE';
        case SqlDialect.sqlite:
          return 'DATETIME';
      }
    }

    // Categoria: Apenas Hora
    if (['TIME'].contains(baseType)) {
      switch (this) {
        case SqlDialect.postgres:
          return 'TIME';
        case SqlDialect.mysql:
        case SqlDialect.sqlite:
          return 'DATETIME';
        case SqlDialect.sqlserver:
          return 'DATETIME2';
        case SqlDialect.oracle:
          return 'TIMESTAMP';
      }
    }

    // Categoria: Binários / Blobs
    if ([
      'BLOB',
      'BYTEA',
      'VARBINARY',
      'RAW',
      'LONGBLOB',
      'MEDIUMBLOB',
      'TINYBLOB',
      'BINARY',
    ].contains(baseType)) {
      switch (this) {
        case SqlDialect.postgres:
          return 'BYTEA';
        case SqlDialect.mysql:
        case SqlDialect.sqlite:
        case SqlDialect.oracle:
          return 'BLOB';
        case SqlDialect.sqlserver:
          return 'VARBINARY';
      }
    }

    // Categoria: JSON
    if (['JSON', 'JSONB'].contains(baseType)) {
      switch (this) {
        case SqlDialect.postgres:
          return 'JSONB';
        case SqlDialect.mysql:
          return 'JSON';
        case SqlDialect.sqlite:
          return 'TEXT';
        case SqlDialect.sqlserver:
          return 'NVARCHAR';
        case SqlDialect.oracle:
          return 'CLOB';
      }
    }

    // Fallback de segurança: retorna o primeiro tipo válido do dialeto destino
    return availableDataTypes.first;
  }

  /// Converte e ajusta o modelo de uma coluna (tipo de dado e autoincremento) para o dialeto atual,
  /// garantindo que no Postgres colunas ID sejam sempre UUID e apenas no SQLite sejam inteiros autoincremento.
  ColumnModel mapColumn(ColumnModel col) {
    final isIdColumn =
        (col.isPrimaryKey &&
            (col.name.toLowerCase() == 'id' ||
                col.name.toLowerCase().endsWith('_id') ||
                [
                  'UUID',
                  'SERIAL',
                  'INT4',
                  'INTEGER',
                  'INT',
                  'BIGINT',
                  'VARCHAR(36)',
                  'UNIQUEIDENTIFIER',
                  'RAW(16)',
                  'AUTO_INCREMENT',
                ].contains(col.dataType.toUpperCase()))) ||
        (col.isForeignKey &&
            (col.name.toLowerCase() == 'id' ||
                col.name.toLowerCase().endsWith('_id') ||
                col.name.toLowerCase().endsWith('id'))) ||
        (col.name.toLowerCase() == 'id');

    if (isIdColumn) {
      return col.copyWith(
        dataType: idDataType,
        isAutoIncrement: col.isPrimaryKey ? idIsAutoIncrement : false,
      );
    }

    final newType = mapDataType(col.dataType);
    bool autoInc = col.isAutoIncrement;
    if (!idIsAutoIncrement) {
      autoInc = false;
    }
    return col.copyWith(dataType: newType, isAutoIncrement: autoInc);
  }
}
