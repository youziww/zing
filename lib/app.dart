import 'package:flutter/cupertino.dart';
import 'screens/deck_list_screen.dart';

class ZingApp extends StatelessWidget {
  const ZingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Zing',
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
      ),
      home: DeckListScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
