import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modelador_db/main.dart';

void main() {
  testWidgets('App initializes correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: DbDiagramApp(),
      ),
    );

    expect(find.byType(DbDiagramApp), findsOneWidget);
  });
}
