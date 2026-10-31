import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/i18n/strings.g.dart';
import 'package:plezy/models/livetv_channel.dart';
import 'package:plezy/media/ids.dart';
import 'package:plezy/media/media_backend.dart';
import 'package:plezy/media/media_item.dart';
import 'package:plezy/media/media_kind.dart';
import 'package:plezy/media/live_tv_support.dart';
import 'package:plezy/screens/video_player/live_tv_session_args.dart';
import 'package:plezy/utils/video_player_navigation.dart';
import 'package:plezy/media/media_server_client.dart';
import 'package:plezy/media/server_capabilities.dart';
import 'package:plezy/providers/multi_server_provider.dart';
import 'package:plezy/screens/video_player_screen.dart';
import 'package:plezy/services/multi_server_manager.dart';
import 'package:plezy/utils/live_tv_player_navigation.dart';

import '../test_helpers/multi_server_fixtures.dart';

void main() {
  late MultiServerManager manager;
  late MultiServerProvider multiServer;

  setUp(() async {
    await LocaleSettings.setLocale(AppLocale.bg);
    manager = MultiServerManager();
    multiServer = testMultiServerProvider(manager);
  });

  tearDown(() {
    multiServer.dispose();
    manager.dispose();
    LocaleSettings.setLocaleSync(AppLocale.en);
  });

  Future<void> pumpLauncher(WidgetTester tester, LiveTvChannel channel) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    navigateToLiveTv(context, multiServer: multiServer, channel: channel, channels: [channel]),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Emby channel without an active recording launches live without a prompt', (tester) async {
    final client = _RecordingClient(ServerId('emby-1'), const []);
    manager.debugRegisterClientForTesting(client);
    multiServer.debugSetLiveTvServersForTesting([LiveTvServerInfo(serverId: 'emby-1', dvrKey: 'dvr-1')]);
    final channel = LiveTvChannel(key: 'channel-1', serverId: 'emby-1', liveDvrKey: 'dvr-1');
    final observer = _PlayerObserver();
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) {
            host = context;
            return const Scaffold();
          },
        ),
      ),
    );
    await navigateToLiveTv(host, multiServer: multiServer, channel: channel, channels: [channel]);
    final route = observer.playerRoute!;
    final screen =
        route.pageBuilder(host, const AlwaysStoppedAnimation(1), const AlwaysStoppedAnimation(1)) as VideoPlayerScreen;
    expect(screen.live!.startPosition, LiveTvStartPosition.live);
    expect(client.requestedChannel, 'channel-1');
    // Inspect the committed launch before the native player mounts.
    Navigator.of(host).removeRoute(route);
    await tester.pumpAndSettle();
    expect(find.text(t.liveTv.joinSession), findsNothing);
  });

  testWidgets('Emby recording channel uses the shared two-choice prompt and can cancel', (tester) async {
    final client = _RecordingClient(ServerId('emby-1'), [
      MediaItem(
        id: 'recording-1',
        backend: MediaBackend.emby,
        kind: MediaKind.clip,
        raw: {
          'IsInProgress': true,
          'StartDate': DateTime.now().subtract(const Duration(minutes: 10)).toUtc().toIso8601String(),
        },
      ).copyWith(viewOffsetMs: 90000),
    ]);
    manager.debugRegisterClientForTesting(client);
    multiServer.debugSetLiveTvServersForTesting([LiveTvServerInfo(serverId: 'emby-1', dvrKey: 'dvr-1')]);
    final channel = LiveTvChannel(key: 'channel-1', serverId: 'emby-1', liveDvrKey: 'dvr-1');
    await pumpLauncher(tester, channel);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text(t.liveTv.joinSession), findsOneWidget);
    expect(find.text(t.liveTv.watchFromStart(minutes: 10)), findsOneWidget);
    expect(find.text(t.liveTv.watchLive), findsOneWidget);
    expect(find.text(t.common.resume), findsNothing);
    Navigator.of(tester.element(find.text(t.liveTv.joinSession))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(VideoPlayerScreen), findsNothing);
  });

  test('overlapping recordings prefer the latest airing', () {
    MediaItem item(String id, String start) =>
        MediaItem(id: id, backend: MediaBackend.emby, kind: MediaKind.clip, raw: {'StartDate': start});
    final older = item('old', '2026-10-30T19:00:00Z');
    final newer = item('new', '2026-10-30T20:00:00Z');
    expect(latestInProgressRecording([older, newer]), same(newer));
    expect(latestInProgressRecording([newer, older]), same(newer));
  });

  test('scoped Live TV selection fails closed and unscoped selection retains fallback', () {
    final aDvr = LiveTvServerInfo(serverId: 'server-a', dvrKey: 'dvr-a');
    final aOtherDvr = LiveTvServerInfo(serverId: 'server-a', dvrKey: 'dvr-other');
    final bDvr = LiveTvServerInfo(serverId: 'server-b', dvrKey: 'dvr-b');

    multiServer.debugSetLiveTvServersForTesting([bDvr]);
    expect(
      liveTvServerInfoForChannel(
        multiServer,
        LiveTvChannel(key: 'channel-a', serverId: 'server-a', liveDvrKey: 'dvr-a'),
      ),
      isNull,
    );

    multiServer.debugSetLiveTvServersForTesting([aOtherDvr, bDvr]);
    expect(
      liveTvServerInfoForChannel(
        multiServer,
        LiveTvChannel(key: 'channel-a', serverId: 'server-a', liveDvrKey: 'dvr-a'),
      ),
      isNull,
      reason: 'an explicit DVR must not relax to another DVR on the same server',
    );
    expect(
      liveTvServerInfoForChannel(multiServer, LiveTvChannel(key: 'channel-a', serverId: 'server-a')),
      same(aOtherDvr),
    );

    multiServer.debugSetLiveTvServersForTesting([bDvr, aDvr]);
    expect(
      liveTvServerInfoForChannel(
        multiServer,
        LiveTvChannel(key: 'channel-a', serverId: 'server-a', liveDvrKey: 'dvr-a'),
      ),
      same(aDvr),
    );
    expect(liveTvServerInfoForChannel(multiServer, LiveTvChannel(key: 'legacy-channel')), same(bDvr));

    multiServer.debugSetLiveTvServersForTesting(const []);
    expect(liveTvServerInfoForChannel(multiServer, LiveTvChannel(key: 'legacy-channel')), isNull);
  });

  testWidgets('missing scoped server is not replaced by an online server', (tester) async {
    manager.debugRegisterClientForTesting(_TestClient(ServerId('server-b')));
    multiServer.debugSetLiveTvServersForTesting([LiveTvServerInfo(serverId: 'server-b', dvrKey: 'dvr-b')]);
    final channel = LiveTvChannel(key: 'channel-a', title: 'Channel A', serverId: 'server-a', liveDvrKey: 'dvr-a');
    await pumpLauncher(tester, channel);

    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(find.byType(VideoPlayerScreen), findsNothing);
    expect(find.text('Сървърът за телевизия на живо не е наличен.'), findsOneWidget);
  });

  testWidgets('unavailable Live TV server error uses the active locale', (tester) async {
    final channel = LiveTvChannel(key: 'channel-1', title: 'Channel');
    await pumpLauncher(tester, channel);

    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(find.text('Сървърът за телевизия на живо не е наличен.'), findsOneWidget);
    expect(find.text('Live TV server is not available.'), findsNothing);
  });

  testWidgets('disconnected Live TV server error uses the active locale', (tester) async {
    const serverId = 'server-1';
    final channel = LiveTvChannel(key: 'channel-1', title: 'Channel', serverId: serverId, liveDvrKey: 'dvr-1');
    multiServer.debugSetLiveTvServersForTesting([LiveTvServerInfo(serverId: serverId, dvrKey: 'dvr-1')]);
    await pumpLauncher(tester, channel);

    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(find.text('Сървърът за телевизия на живо не е свързан.'), findsOneWidget);
    expect(find.text('Live TV server is not connected.'), findsNothing);
  });
}

class _TestClient implements MediaServerClient {
  _TestClient(this.serverId);

  @override
  final ServerId serverId;

  @override
  String? get serverName => 'Test server';

  @override
  MediaBackend get backend => MediaBackend.jellyfin;

  @override
  ServerCapabilities get capabilities => const ServerCapabilities(liveTv: true);

  @override
  void close() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingClient extends _TestClient implements InProgressRecordingSupport {
  _RecordingClient(super.serverId, this.recordings);
  final List<MediaItem> recordings;
  String? requestedChannel;
  @override
  MediaBackend get backend => MediaBackend.emby;
  @override
  Future<List<MediaItem>> fetchInProgressRecordings({String? channelId}) async {
    requestedChannel = channelId;
    return recordings;
  }
}

class _PlayerObserver extends NavigatorObserver {
  VideoPlayerRoute? playerRoute;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is VideoPlayerRoute) playerRoute = route;
  }
}
