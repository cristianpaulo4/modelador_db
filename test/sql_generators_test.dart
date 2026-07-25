import 'package:flutter_test/flutter_test.dart';
import 'package:modelador_db/data/models/column_model.dart';
import 'package:modelador_db/data/models/relationship_model.dart';
import 'package:modelador_db/data/models/table_model.dart';
import 'package:modelador_db/generators/sql_dialect.dart';
import 'package:modelador_db/generators/sql_dialect_generator.dart';

void main() {
  group('SQL Dialect Generators Tests', () {
    final sampleTables = [
      TableModel(
        id: 't1',
        name: 'users',
        schema: 'public',
        position: Offset.zero,
        columns: const [
          ColumnModel(
            id: 'c1',
            name: 'id',
            dataType: 'INT4',
            isPrimaryKey: true,
            isNotNull: true,
          ),
          ColumnModel(
            id: 'c2',
            name: 'name',
            dataType: 'VARCHAR',
            lengthOrPrecision: '100',
          ),
        ],
      ),
      TableModel(
        id: 't2',
        name: 'orders',
        schema: 'public',
        position: Offset.zero,
        columns: const [
          ColumnModel(
            id: 'c3',
            name: 'id',
            dataType: 'INT4',
            isPrimaryKey: true,
            isNotNull: true,
          ),
          ColumnModel(
            id: 'c4',
            name: 'user_id',
            dataType: 'INT4',
            isForeignKey: true,
          ),
        ],
      ),
    ];

    final sampleRels = [
      const RelationshipModel(
        id: 'r1',
        sourceTableId: 't2',
        targetTableId: 't1',
        sourceColumnId: 'c4',
        targetColumnId: 'c1',
        cardinality: CardinalityType.oneToMany,
        onDelete: ReferentialAction.cascade,
      ),
    ];

    test('PostgreSQL Generator produces valid DDL', () {
      final gen = SqlDialectGenerator.forDialect(SqlDialect.postgres);
      final ddl = gen.generateDdl(sampleTables, sampleRels);

      expect(ddl, contains('CREATE TABLE "users"'));
      expect(ddl, contains('CREATE TABLE "orders"'));
      expect(ddl, contains('ALTER TABLE "orders"'));
      expect(ddl, contains('ON DELETE CASCADE'));
    });

    test('MySQL Generator produces valid DDL', () {
      final gen = SqlDialectGenerator.forDialect(SqlDialect.mysql);
      final ddl = gen.generateDdl(sampleTables, sampleRels);

      expect(ddl, contains('CREATE TABLE `users`'));
      expect(ddl, contains('ENGINE=InnoDB'));
    });

    test('SQLite Generator produces valid DDL', () {
      final gen = SqlDialectGenerator.forDialect(SqlDialect.sqlite);
      final ddl = gen.generateDdl(sampleTables, sampleRels);

      expect(ddl, contains('CREATE TABLE IF NOT EXISTS "users"'));
      expect(ddl, contains('PRAGMA foreign_keys = ON;'));
      expect(ddl, isNot(contains('ALTER TABLE')));
      expect(ddl, contains('CREATE UNIQUE INDEX IF NOT EXISTS'));
    });

    test('SQL Server Generator produces valid DDL', () {
      final gen = SqlDialectGenerator.forDialect(SqlDialect.sqlserver);
      final ddl = gen.generateDdl(sampleTables, sampleRels);

      expect(ddl, contains('CREATE TABLE [public].[users]'));
      expect(ddl, contains('GO'));
    });

    test('Oracle Generator produces valid DDL', () {
      final gen = SqlDialectGenerator.forDialect(SqlDialect.oracle);
      final ddl = gen.generateDdl(sampleTables, sampleRels);

      expect(ddl, contains('CREATE TABLE "USERS"'));
      expect(ddl, contains('CONSTRAINT "PK_USERS" PRIMARY KEY'));
    });
  });
}
