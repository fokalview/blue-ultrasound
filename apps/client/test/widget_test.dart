import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blue_ultrasound/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('desktop demo capture and disconnect', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const BlueApp());
    await tester.pump();
    expect(find.text('NO SOURCE CONNECTED'), findsOneWidget);
    await tester.tap(find.text('Start demo'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('SIMULATED · 8 FPS'), findsOneWidget);
    await tester.tap(find.text('Freeze'));
    await tester.pump();
    expect(find.text('SIMULATED · FROZEN'), findsOneWidget);
    await tester.tap(find.text('Capture'));
    await tester.pump();
    expect(find.text('Studies (1)'), findsOneWidget);
    await tester.tap(find.text('Disconnect'));
    await tester.pump();
    expect(find.text('NO SOURCE CONNECTED'), findsOneWidget);
    await tester.tap(find.text('Studies (1)'));
    await tester.pump();
    expect(find.textContaining('Demo capture'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('narrow Android layout has no overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const BlueApp());
    await tester.pump();
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('Devices'));
    await tester.pump();
    expect(find.text('GE Vscan Air'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Storage'));
    await tester.pump();
    expect(find.text('Create vault'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
