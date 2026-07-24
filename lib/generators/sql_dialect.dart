enum SqlDialect {
  postgres('PostgreSQL', 'postgresql'),
  mysql('MySQL / MariaDB', 'mysql'),
  sqlite('SQLite', 'sqlite'),
  sqlserver('SQL Server (T-SQL)', 'sqlserver'),
  oracle('Oracle DB', 'oracle');

  final String displayName;
  final String code;

  const SqlDialect(this.displayName, this.code);

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
}
