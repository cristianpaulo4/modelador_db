import 'package:flutter_test/flutter_test.dart';
import 'package:modelador_db/state/canvas_provider.dart';

void main() {
  group('CanvasNotifier.deleteRelationship Tests', () {
    test('Should remove the FK column from the referring table card when deleting a relationship', () {
      final notifier = CanvasNotifier();
      notifier.createSampleData();
      
      // A inicialização cria a tabela users e orders, onde orders tem a coluna user_id como FK
      expect(notifier.state.tables.length, 2);
      expect(notifier.state.relationships.length, 1);

      final rel = notifier.state.relationships.first;
      final ordersTableBefore = notifier.state.tables.firstWhere((t) => t.name == 'orders');
      final fkColBefore = ordersTableBefore.columns.where((c) => c.id == rel.sourceColumnId).firstOrNull;
      
      expect(fkColBefore, isNotNull);
      expect(fkColBefore!.isForeignKey, isTrue);
      expect(ordersTableBefore.columns.length, 4);

      // Deletar o relacionamento
      notifier.deleteRelationship(rel.id);

      // O relacionamento foi removido
      expect(notifier.state.relationships.isEmpty, isTrue);

      // A coluna FK correspondente na tabela referente deve ter sido excluída
      final ordersTableAfter = notifier.state.tables.firstWhere((t) => t.name == 'orders');
      final fkColAfter = ordersTableAfter.columns.where((c) => c.id == rel.sourceColumnId).firstOrNull;
      
      expect(fkColAfter, isNull);
      expect(ordersTableAfter.columns.length, 3);
    });
  });
}
