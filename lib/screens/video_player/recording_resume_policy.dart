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
