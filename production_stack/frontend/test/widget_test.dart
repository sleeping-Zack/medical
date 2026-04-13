import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medapp_flutter/app.dart';

void main() {
  testWidgets('MedApp 可构建', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MedApp()));
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
