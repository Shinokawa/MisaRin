import 'package:fluent_ui/fluent_ui.dart';

import 'view/home_page.dart';

class MisarinApp extends StatelessWidget {
  const MisarinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      debugShowCheckedModeBanner: false,
      title: 'misa rin',
      theme: FluentThemeData(
        brightness: Brightness.light,
        accentColor: Colors.blue,
      ),
      home: const MisarinHomePage(),
    );
  }
}
