import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/media/library_query.dart';
import 'package:plezy/media/media_kind.dart';

import '../test_helpers/backend_client_fixtures.dart';
import '../test_helpers/http_fixtures.dart';

void main() {
  test('Emby active recordings are user/channel scoped and playable', () async {
    final client = testEmbyClient(
      handler: (request) async {
        expect(request.url.path, '/LiveTv/Recordings');
        expect(request.url.queryParameters['UserId'], 'user-1');
        expect(request.url.queryParameters['ChannelId'], 'channel-1');
        expect(request.url.queryParameters['IsInProgress'], 'true');
        return jsonResponse({
          'Items': [
            {
              'Id': 'recording-1',
              'ChannelId': 'channel-1',
              'Type': 'Recording',
              'Name': 'Still recording',
              'UserData': {'PlaybackPositionTicks': 900000000},
            },
          ],
        });
      },
    );
    addTearDown(client.close);
    final recordings = await client.fetchInProgressRecordings(channelId: 'channel-1');
    expect(recordings.single.id, 'recording-1');
    expect(recordings.single.isRecordingInProgress, isTrue);
    expect(recordings.single.viewOffsetMs, 90000);
    expect(recordings.single.hasActiveProgress, isTrue);
    expect(recordings.single.kind, MediaKind.clip);
    expect(recordings.single.kind.isPlayable, isTrue);
  });

  test('channel prompt excludes unrelated and unidentified recordings when server filtering is ignored', () async {
    final client = testEmbyClient(
      handler: (request) async => jsonResponse({
        'Items': [
          {'Id': 'other-channel', 'ChannelId': 'channel-2', 'Type': 'Recording'},
          {'Id': 'matching-channel', 'ChannelId': 'channel-1', 'Type': 'Recording'},
          {'Id': 'unknown-channel', 'Type': 'Recording'},
        ],
      }),
    );
    addTearDown(client.close);
    expect((await client.fetchInProgressRecordings(channelId: 'channel-1')).map((item) => item.id), [
      'matching-channel',
    ]);
    expect(await client.fetchInProgressRecordings(channelId: 'channel-3'), isEmpty);
    // The Recordings tab still requests and displays every active recording.
    expect(await client.fetchInProgressRecordings(), hasLength(3));
  });

  test('Emby recording folders use the DVR recording endpoint for paged browsing', () async {
    var queriedRecordings = false;
    final client = testEmbyClient(
      handler: (request) async {
        switch (request.url.path) {
          case '/Users/user-1/Views':
            return jsonResponse({
              'Items': [
                {'Id': 'dvr-folder', 'Type': 'CollectionFolder', 'Name': 'My DVR', 'CollectionType': 'mixed'},
              ],
            });
          case '/LiveTv/Recordings/Folders':
            return jsonResponse({
              'Items': [
                {'Id': 'dvr-folder', 'Name': 'My DVR'},
              ],
            });
          case '/LiveTv/Recordings':
            queriedRecordings = true;
            expect(request.url.queryParameters['ParentId'], 'dvr-folder');
            expect(request.url.queryParameters['Recursive'], 'true');
            expect(request.url.queryParameters.containsKey('IncludeItemTypes'), isFalse);
            return jsonResponse({
              'Items': [
                {'Id': 'growing-file', 'Type': 'Recording', 'Name': 'Still recording'},
              ],
              'TotalRecordCount': 1,
            });
          default:
            fail('Unexpected request: ${request.url}');
        }
      },
    );
    addTearDown(client.close);
    await client.fetchLibraries();
    final page = await client.fetchLibraryPagedContent('dvr-folder', query: const LibraryQuery());
    expect(queriedRecordings, isTrue);
    expect(page.items.single.id, 'growing-file');
    expect(page.totalCount, 1);
  });
  test('virtual Live TV view is hidden while the real Recorded TV library remains', () async {
    final client = testEmbyClient(
      handler: (request) async {
        if (request.url.path == '/Users/user-1/Views') {
          return jsonResponse({
            'Items': [
              {'Id': 'virtual-live', 'Type': 'UserView', 'Name': 'Live TV', 'CollectionType': 'livetv'},
              {'Id': 'real-dvr', 'Type': 'CollectionFolder', 'Name': 'Recorded TV', 'CollectionType': 'mixed'},
            ],
          });
        }
        if (request.url.path == '/LiveTv/Recordings/Folders') {
          return jsonResponse({
            'Items': [
              {'Id': 'real-dvr'},
            ],
          });
        }
        fail('Unexpected request: ${request.url}');
      },
    );
    addTearDown(client.close);
    expect((await client.fetchLibraries()).map((item) => item.id), ['real-dvr']);
  });

  test('stopping a growing recording reports its final resume position', () async {
    final client = testEmbyClient(
      handler: (request) async {
        expect(request.url.path, '/Sessions/Playing/Stopped');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['ItemId'], 'recording-1');
        expect(body['PositionTicks'], 900000000);
        return jsonResponse({}, status: 204);
      },
    );
    addTearDown(client.close);
    await client.reportPlaybackStopped(itemId: 'recording-1', position: const Duration(seconds: 90));
  });
}
