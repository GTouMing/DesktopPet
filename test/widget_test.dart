import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:desktop_pet/app.dart';
import 'package:desktop_pet/platform/window_interface.dart';

class FakeWindowController implements WindowController {
  @override String get id => 'fake';
  @override Future<void> mainInit() async {}
  @override Future<void> petInit() async {}
  @override Future<void> show() async {}
  @override Future<void> hide() async {}
  @override Future<void> setIgnoreMouseEvents(bool ignore) async {}
  @override Future<Offset> getPosition() async => Offset.zero;
  @override Future<void> setPosition(Offset pos) async {}
  @override Future<void> moveRelative(Offset delta) async {}
  @override Future<void> setSize(Size size) async {}
  @override Future<void> setAlwaysOnTop(bool value) async {}
  @override Future<void> close() async {}
  @override void dispose() {}
  @override Future<Size> getScreenSize() async => Size.zero;

  @override
  // TODO: implement devicePixelRatio
  double get devicePixelRatio => throw UnimplementedError();

  @override
  void setPositionSync(Offset pos) {
    // TODO: implement setPositionSync
  }

  @override
  Future<void> startDragging() {
    // TODO: implement startDragging
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: PetApp(),
      ),
    );
    expect(find.byType(PetApp), findsOneWidget);
  });
}
