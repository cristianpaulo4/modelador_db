import '../data/models/table_model.dart';
import '../data/models/relationship_model.dart';
import 'sql_dialect.dart';
import 'postgresql_generator.dart';
import 'mysql_generator.dart';
import 'sqlite_generator.dart';
import 'sqlserver_generator.dart';
import 'oracle_generator.dart';

abstract class SqlDialectGenerator {
  SqlDialect get dialect;

  /// Gera o script DDL completo para a lista de tabelas e relacionamentos fornecida.
  String generateDdl(List<TableModel> tables, List<RelationshipModel> relationships);

  factory SqlDialectGenerator.forDialect(SqlDialect dialect) {
    switch (dialect) {
      case SqlDialect.postgres:
        return PostgresqlGenerator();
      case SqlDialect.mysql:
        return MysqlGenerator();
      case SqlDialect.sqlite:
        return SqliteGenerator();
      case SqlDialect.sqlserver:
        return SqlserverGenerator();
      case SqlDialect.oracle:
        return OracleGenerator();
    }
  }
}
