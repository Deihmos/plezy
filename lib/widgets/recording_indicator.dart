import 'package:flutter/material.dart';

import '../i18n/strings.g.dart';

/// Stack overlay: opposite the watched indicator in the top right corner.
class RecordingIndicator extends StatelessWidget {
  const RecordingIndicator({super.key});

  @override
  Widget build(BuildContext context) => Positioned(
    top: 6,
    left: 6,
    child: Tooltip(
      message: t.liveTv.recordingInProgress,
      child: Semantics(
        label: t.liveTv.recordingInProgress,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ),
    ),
  );
}
