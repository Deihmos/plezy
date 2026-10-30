/// Some growing files ignore the pre-prepare start position, but accept
/// seeks once their first frame is available. Never override a seek that
/// already landed, a deliberate restart, or ordinary on-demand playback.
bool shouldRestoreRecordingResume({
  required bool isRecordingInProgress,
  required Duration requested,
  required Duration actual,
}) =>
    isRecordingInProgress &&
    requested > const Duration(seconds: 2) &&
    actual >= Duration.zero &&
    actual < const Duration(seconds: 2) &&
    requested - actual > const Duration(seconds: 2);

/// The state at first-frame time may still contain the optimistic bookmark
/// seeded by open(). Only a subsequent player position can confirm a seek.
Future<bool> waitForRecordingResumeDecision({
  required bool isRecordingInProgress,
  required Duration requested,
  required Stream<Duration> positions,
}) async {
  if (!isRecordingInProgress || requested <= const Duration(seconds: 2)) return false;
  final actual = await positions.timeout(const Duration(seconds: 5)).first;
  return shouldRestoreRecordingResume(
    isRecordingInProgress: isRecordingInProgress,
    requested: requested,
    actual: actual,
  );
}
