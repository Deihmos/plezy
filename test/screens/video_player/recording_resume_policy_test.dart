import 'package:flutter_test/flutter_test.dart';
import 'package:plezy/screens/video_player/recording_resume_policy.dart';

void main() {
  test('retry a growing recording start ignored at zero', () {
    expect(
      shouldRestoreRecordingResume(
        isRecordingInProgress: true,
        requested: const Duration(minutes: 5),
        actual: Duration.zero,
      ),
      isTrue,
    );
  });
  test('never retry a restart, ordinary file, or a seek that already landed', () {
    for (final sample in [
      (active: true, requested: Duration.zero, actual: Duration.zero),
      (active: false, requested: const Duration(minutes: 5), actual: Duration.zero),
      (active: true, requested: const Duration(minutes: 5), actual: const Duration(minutes: 5)),
      (active: true, requested: const Duration(minutes: 5), actual: const Duration(seconds: 20)),
    ]) {
      expect(
        shouldRestoreRecordingResume(
          isRecordingInProgress: sample.active,
          requested: sample.requested,
          actual: sample.actual,
        ),
        isFalse,
      );
    }
  });
  test('waits for a reported position rather than trusting the optimistic bookmark', () async {
    expect(
      await waitForRecordingResumeDecision(
        isRecordingInProgress: true,
        requested: const Duration(seconds: 90),
        positions: Stream.value(Duration.zero),
      ),
      isTrue,
    );
    expect(
      await waitForRecordingResumeDecision(
        isRecordingInProgress: true,
        requested: const Duration(seconds: 90),
        positions: Stream.value(const Duration(seconds: 90)),
      ),
      isFalse,
    );
  });
}
