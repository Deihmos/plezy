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
            {'Id': 'recording-1', 'Type': 'Recording', 'Name': 'Still recording', 'IsInProgress': true},
          ],
        });
      },
    );
    addTearDown(client.close);
    final recordings = await client.fetchInProgressRecordings(channelId: 'channel-1');
    expect(recordings.single.id, 'recording-1');
    expect(recordings.single.kind, MediaKind.clip);
    expect(recordings.single.kind.isPlayable, isTrue);
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
}
