import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'home.dart';
import 'shared_widgets.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.dumpErrorToConsole(details);
        debugPrint('Flutter framework error: ${details.exceptionAsString()}');
        debugPrintStack(stackTrace: details.stack);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('Unhandled platform error: $error');
        debugPrintStack(stackTrace: stack);
        return true;
      };

      ErrorWidget.builder = (details) => Directionality(
            textDirection: TextDirection.ltr,
            child: Material(
              color: const Color(0xFFF8F5F7),
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: appPink,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '화면을 표시하는 중 문제가 발생했습니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '앱은 종료하지 않고 안전 화면으로 전환했습니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                        if (kDebugMode) ...[
                          const SizedBox(height: 10),
                          Text(
                            details.exceptionAsString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );

      final controller = AppController();
      runApp(CinemaSeatAlertApp(controller: controller));

      unawaited(
        controller.initialize().catchError((Object error, StackTrace stack) {
          debugPrint('Controller initialization failed safely: $error');
          debugPrintStack(stackTrace: stack);
        }),
      );
    },
    (error, stack) {
      debugPrint('Unhandled zoned error: $error');
      debugPrintStack(stackTrace: stack);
    },
  );
}

class CinemaSeatAlertApp extends StatelessWidget {
  const CinemaSeatAlertApp({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '시네시트',
        theme: buildTheme(),
        home: AppShell(controller: controller),
      );
}
