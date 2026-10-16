import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_punch/app/app.dart';
import 'package:pixel_punch/core/widgets/pixel_punch_logo.dart';

void main() {
  testWidgets('PixelPunch app launches into splash and displays logo', (WidgetTester tester) async {
    // Provide a portrait screen size for testing (default mobile orientation)
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(const PixelPunchApp());

    // Verify game logo widget and tagline are present on the splash screen
    expect(find.byType(PixelPunchLogoWidget), findsOneWidget);
    expect(find.text('Your Zone. Your Rivals. Your Victory.'), findsOneWidget);

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
