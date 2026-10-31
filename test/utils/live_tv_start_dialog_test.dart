import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/utils/live_tv_start_dialog.dart';

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  for (final fromStart in [true, false]) {
    testWidgets('shared Live TV prompt returns $fromStart without a Resume option', (tester) async {
      late BuildContext host;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              host = context;
              return const Scaffold();
            },
          ),
        ),
      );
      final result = showLiveTvWatchFromStartDialog(host, 1000, 1600);
      await tester.pumpAndSettle();
      expect(find.text(t.liveTv.joinSession), findsOneWidget);
      expect(find.text(t.liveTv.watchFromStart(minutes: 10)), findsOneWidget);
      expect(find.text(t.liveTv.watchLive), findsOneWidget);
      expect(find.text(t.common.resume), findsNothing);
      await tester.tap(find.text(fromStart ? t.liveTv.watchFromStart(minutes: 10) : t.liveTv.watchLive));
      await tester.pumpAndSettle();
      expect(await result, fromStart);
    });
  }
}
