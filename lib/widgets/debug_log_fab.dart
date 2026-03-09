import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tg_video_downloader/services/debug_log_service.dart';
import 'package:tg_video_downloader/widgets/debug_log_screen.dart';

class DebugLogFab extends StatelessWidget {
  const DebugLogFab({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.select<DebugLogService, int>((s) => s.entries.length);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(right: 16, bottom: 16),
        child: Align(
          alignment: Alignment.bottomRight,
          child: FloatingActionButton.small(
            heroTag: 'debug-log-fab',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DebugLogScreen()),
              );
            },
            child: Badge(
              isLabelVisible: count > 0,
              label: Text('$count'),
              child: const Icon(Icons.bug_report_outlined),
            ),
          ),
        ),
      ),
    );
  }
}
