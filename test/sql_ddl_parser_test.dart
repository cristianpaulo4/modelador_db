import 'package:flutter_test/flutter_test.dart';
import 'package:modelador_db/parsers/sql_ddl_parser.dart';

void main() {
  group('SqlDdlParser Tests', () {
    test('Parses CREATE TABLE with inline and table level FK constraints', () {
      const sql = '''
        CREATE TABLE users (
          id INT PRIMARY KEY AUTO_INCREMENT,
          name VARCHAR(100) NOT NULL
        );

        CREATE TABLE orders (
          id INT PRIMARY KEY,
          user_id INT REFERENCES users(id) ON DELETE CASCADE,
          total NUMERIC(10,2)
        );

        CREATE TABLE order_items (
          id INT PRIMARY KEY,
          order_id INT NOT NULL,
          product_name VARCHAR(100),
          CONSTRAINT fk_items_orders FOREIGN KEY (order_id) REFERENCES orders(id)
        );
      ''';

      final result = SqlDdlParser.parseSqlScript(sql);

      expect(result.tables.length, equals(3));
      expect(result.relationships.length, equals(2));

      final usersTable = result.tables.firstWhere((t) => t.name == 'users');
      final ordersTable = result.tables.firstWhere((t) => t.name == 'orders');
      final itemsTable = result.tables.firstWhere((t) => t.name == 'order_items');

      expect(usersTable.columns.length, equals(2));
      expect(ordersTable.columns.length, equals(3));
      expect(itemsTable.columns.length, equals(3));

      final rel1 = result.relationships.firstWhere((r) => r.sourceTableId == ordersTable.id);
      expect(rel1.targetTableId, equals(usersTable.id));

      final rel2 = result.relationships.firstWhere((r) => r.sourceTableId == itemsTable.id);
      expect(rel2.targetTableId, equals(ordersTable.id));
    });

    test('Parses ALTER TABLE FOREIGN KEY constraints', () {
      const sql = '''
        CREATE TABLE categories (
          id INT PRIMARY KEY,
          title VARCHAR(50)
        );

        CREATE TABLE products (
          id INT PRIMARY KEY,
          category_id INT
        );

        ALTER TABLE products ADD CONSTRAINT fk_prod_cat FOREIGN KEY (category_id) REFERENCES categories (id);
      ''';

      final result = SqlDdlParser.parseSqlScript(sql);

      expect(result.tables.length, equals(2));
      expect(result.relationships.length, equals(1));

      final prodTable = result.tables.firstWhere((t) => t.name == 'products');
      final catTable = result.tables.firstWhere((t) => t.name == 'categories');

      final rel = result.relationships.first;
      expect(rel.sourceTableId, equals(prodTable.id));
      expect(rel.targetTableId, equals(catTable.id));
    });
  });
}
