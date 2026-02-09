import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/preload_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PreloadService.preloadIfWeb();
  runApp(const ProviderScope(child: ZingApp()));
}
