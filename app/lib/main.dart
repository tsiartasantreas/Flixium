import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/data/background_download_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  BackgroundDownloadService.initialize();
  runApp(const WithForegroundTask(child: FlixiumApp()));
}
