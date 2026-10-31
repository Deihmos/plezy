import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../i18n/strings.g.dart';
import 'dialogs.dart';

/// The shared Plex and Emby "Watch from Start" / "Watch Live" choice.
Future<bool?> showLiveTvWatchFromStartDialog(BuildContext context, int effectiveStartEpoch, int nowEpoch) {
  final minutesAgo = ((nowEpoch - effectiveStartEpoch) / 60).round().clamp(0, 1 << 30);
  return showOptionPickerDialog<bool>(
    context,
    title: t.liveTv.joinSession,
    options: [
      (icon: Symbols.replay_rounded, label: t.liveTv.watchFromStart(minutes: minutesAgo), value: true),
      (icon: Symbols.live_tv_rounded, label: t.liveTv.watchLive, value: false),
    ],
  );
}
