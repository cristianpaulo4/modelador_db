import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modelador_db/data/models/column_model.dart';
import 'package:modelador_db/data/models/table_model.dart';
import 'package:modelador_db/generators/sql_dialect.dart';
import 'package:modelador_db/state/canvas_provider.dart';

void main() {
  group('SqlDialect.mapDataType Direct Mapping Tests', () {
    test('Conversions to PostgreSQL', () {
      final dialect = SqlDialect.postgres;
      expect(dialect.mapDataType('VARCHAR'), 'VARCHAR');
      expect(dialect.mapDataType('VARCHAR2'), 'VARCHAR');
      expect(dialect.mapDataType('TEXT'), 'TEXT');
      expect(dialect.mapDataType('CLOB'), 'TEXT');
      expect(dialect.mapDataType('INTEGER'), 'INT4');
      expect(dialect.mapDataType('INT'), 'INT4');
      expect(dialect.mapDataType('AUTO_INCREMENT'), 'SERIAL');
      expect(dialect.mapDataType('TINYINT(1)'), 'BOOLEAN');
      expect(dialect.mapDataType('BIT'), 'BOOLEAN');
      expect(dialect.mapDataType('DATETIME2'), 'TIMESTAMP');
      expect(dialect.mapDataType('JSON'), 'JSONB');
      expect(dialect.mapDataType('RAW(16)'), 'UUID');
    });

    test('Conversions to MySQL', () {
      final dialect = SqlDialect.mysql;
      expect(dialect.mapDataType('VARCHAR'), 'VARCHAR');
      expect(dialect.mapDataType('TEXT'), 'TEXT');
      expect(dialect.mapDataType('INT4'), 'INT');
      expect(dialect.mapDataType('SERIAL'), 'AUTO_INCREMENT');
      expect(dialect.mapDataType('BOOLEAN'), 'TINYINT(1)');
      expect(dialect.mapDataType('JSONB'), 'JSON');
      expect(dialect.mapDataType('BYTEA'), 'BLOB');
      expect(dialect.mapDataType('UUID'), 'VARCHAR(36)');
    });

    test('Conversions to SQLite', () {
      final dialect = SqlDialect.sqlite;
      expect(dialect.mapDataType('VARCHAR'), 'TEXT');
      expect(dialect.mapDataType('VARCHAR2'), 'TEXT');
      expect(dialect.mapDataType('NVARCHAR'), 'TEXT');
      expect(dialect.mapDataType('INT4'), 'INTEGER');
      expect(dialect.mapDataType('SERIAL'), 'INTEGER');
      expect(dialect.mapDataType('BIGINT'), 'INTEGER');
      expect(dialect.mapDataType('BOOLEAN'), 'BOOLEAN');
      expect(dialect.mapDataType('JSONB'), 'TEXT');
      expect(dialect.mapDataType('UUID'), 'TEXT');
    });

    test('Conversions to SQL Server (T-SQL)', () {
      final dialect = SqlDialect.sqlserver;
      expect(dialect.mapDataType('VARCHAR'), 'VARCHAR');
      expect(dialect.mapDataType('TEXT'), 'TEXT');
      expect(dialect.mapDataType('INT4'), 'INT');
      expect(dialect.mapDataType('SERIAL'), 'INT');
      expect(dialect.mapDataType('BOOLEAN'), 'BIT');
      expect(dialect.mapDataType('TIMESTAMP'), 'DATETIME2');
      expect(dialect.mapDataType('BYTEA'), 'VARBINARY');
      expect(dialect.mapDataType('UUID'), 'UNIQUEIDENTIFIER');
    });

    test('Conversions to Oracle DB', () {
      final dialect = SqlDialect.oracle;
      expect(dialect.mapDataType('VARCHAR'), 'VARCHAR2');
      expect(dialect.mapDataType('NVARCHAR'), 'VARCHAR2');
      expect(dialect.mapDataType('TEXT'), 'CLOB');
      expect(dialect.mapDataType('INT4'), 'NUMBER');
      expect(dialect.mapDataType('INT'), 'NUMBER');
      expect(dialect.mapDataType('SERIAL'), 'NUMBER');
      expect(dialect.mapDataType('BOOLEAN'), 'NUMBER');
      expect(dialect.mapDataType('UUID'), 'RAW(16)');
    });

    test('Parametric type handling (e.g. VARCHAR(255), DECIMAL(10,2))', () {
      expect(SqlDialect.sqlite.mapDataType('VARCHAR(255)'), 'TEXT');
      expect(SqlDialect.oracle.mapDataType('VARCHAR(100)'), 'VARCHAR2');
      expect(SqlDialect.postgres.mapDataType('DECIMAL(10,2)'), 'NUMERIC');
    });

    test(
      'ID default mapping rules (PostgreSQL always UUID, SQLite always INTEGER autoincrement)',
      () {
        expect(SqlDialect.postgres.idDataType, 'UUID');
        expect(SqlDialect.postgres.idIsAutoIncrement, false);

        expect(SqlDialect.sqlite.idDataType, 'INTEGER');
        expect(SqlDialect.sqlite.idIsAutoIncrement, true);

        expect(SqlDialect.mysql.idDataType, 'VARCHAR(36)');
        expect(SqlDialect.mysql.idIsAutoIncrement, false);
      },
    );
  });

  group('CanvasNotifier.setDialect Integration Tests', () {
    test(
      'Automatically adjusts column data types across all tables when dialect changes',
      () {
        final notifier = CanvasNotifier();

        // Adicionar tabela de teste
        final table = TableModel(
          id: 't_users',
          name: 'users',
          schema: 'public',
          position: Offset.zero,
          columns: const [
            ColumnModel(
              id: 'c1',
              name: 'id',
              dataType: 'UUID',
              isPrimaryKey: true,
            ),
            ColumnModel(
              id: 'c2',
              name: 'username',
              dataType: 'VARCHAR',
              lengthOrPrecision: '50',
            ),
            ColumnModel(id: 'c3', name: 'is_active', dataType: 'BOOLEAN'),
            ColumnModel(id: 'c4', name: 'metadata', dataType: 'JSONB'),
          ],
        );

        notifier.importDdlResult([table], []);
        expect(notifier.state.activeDialect, SqlDialect.postgres);
        expect(notifier.state.tables.first.columns[0].dataType, 'UUID');
        expect(notifier.state.tables.first.columns[0].isAutoIncrement, false);
        expect(notifier.state.tables.first.columns[1].dataType, 'VARCHAR');
        expect(notifier.state.tables.first.columns[2].dataType, 'BOOLEAN');
        expect(notifier.state.tables.first.columns[3].dataType, 'JSONB');

        // 1. Mudar para SQLite
        notifier.setDialect(SqlDialect.sqlite);
        expect(notifier.state.activeDialect, SqlDialect.sqlite);
        var cols = notifier.state.tables.first.columns;
        expect(cols[0].dataType, 'INTEGER'); // UUID (id PK) -> INTEGER
        expect(
          cols[0].isAutoIncrement,
          true,
        ); // SQLite PK id -> autoincrement true
        expect(cols[1].dataType, 'TEXT'); // VARCHAR -> TEXT
        expect(cols[2].dataType, 'BOOLEAN'); // BOOLEAN -> BOOLEAN
        expect(cols[3].dataType, 'TEXT'); // JSONB -> TEXT

        // 2. Mudar para MySQL
        notifier.setDialect(SqlDialect.mysql);
        expect(notifier.state.activeDialect, SqlDialect.mysql);
        cols = notifier.state.tables.first.columns;
        expect(cols[0].dataType, 'VARCHAR(36)'); // ID -> VARCHAR(36)
        expect(cols[0].isAutoIncrement, false);
        expect(cols[1].dataType, 'TEXT'); // TEXT -> TEXT
        expect(cols[2].dataType, 'TINYINT(1)'); // BOOLEAN -> TINYINT(1)
        expect(
          cols[3].dataType,
          'TEXT',
        ); // TEXT -> TEXT (mantém TEXT pois já é válido em MySQL)

        // 3. Mudar para SQL Server
        notifier.setDialect(SqlDialect.sqlserver);
        expect(notifier.state.activeDialect, SqlDialect.sqlserver);
        cols = notifier.state.tables.first.columns;
        expect(cols[0].dataType, 'UNIQUEIDENTIFIER'); // ID -> UNIQUEIDENTIFIER
        expect(cols[1].dataType, 'TEXT'); // TEXT -> TEXT
        expect(cols[2].dataType, 'BIT'); // TINYINT(1) -> BIT

        // 4. Mudar para Oracle DB
        notifier.setDialect(SqlDialect.oracle);
        expect(notifier.state.activeDialect, SqlDialect.oracle);
        cols = notifier.state.tables.first.columns;
        expect(cols[0].dataType, 'RAW(16)'); // ID -> RAW(16)
        expect(cols[1].dataType, 'CLOB'); // TEXT -> CLOB
        expect(cols[2].dataType, 'NUMBER'); // BIT -> NUMBER

        // 5. Retornar para PostgreSQL
        notifier.setDialect(SqlDialect.postgres);
        expect(notifier.state.activeDialect, SqlDialect.postgres);
        cols = notifier.state.tables.first.columns;
        expect(cols[0].dataType, 'UUID'); // ID -> UUID sempre no Postgres
        expect(cols[0].isAutoIncrement, false);
      },
    );

    test(
      'importDdlResult updates activeDialect when provided from saved schema',
      () {
        final notifier = CanvasNotifier();
        expect(notifier.state.activeDialect, SqlDialect.postgres);

        notifier.importDdlResult([], [], dialect: SqlDialect.sqlite);
        expect(notifier.state.activeDialect, SqlDialect.sqlite);
      },
    );
  });
}
