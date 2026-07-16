import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhiyu/app.dart';
import 'package:zhiyu/core/theme/app_theme.dart';
import 'package:zhiyu/data/repositories/auth_repository.dart';

const Size phone390 = Size(390, 844);
const Size phone360 = Size(360, 800);
const Size phone430 = Size(430, 932);

Future<void> pumpPage(
  WidgetTester tester,
  Widget page, {
  Size size = phone390,
  List<Override> overrides = const <Override>[],
  bool disableAnimations = true,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            disableAnimations: disableAnimations,
            textScaler: textScaler,
          ),
          child: page,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pumpZhiyuApp(
  WidgetTester tester, {
  Map<String, Object> preferences = const <String, Object>{},
  Size size = phone390,
}) async {
  SharedPreferences.setMockInitialValues(preferences);
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ZhiyuApp(),
    ),
  );
  await tester.pumpAndSettle();
}
