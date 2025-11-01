import 'package:fluent_ui/fluent_ui.dart';

import '../widgets/painting_board.dart';

class MisarinHomePage extends StatefulWidget {
  const MisarinHomePage({super.key});

  @override
  State<MisarinHomePage> createState() => _MisarinHomePageState();
}

class _MisarinHomePageState extends State<MisarinHomePage> {
  bool _penSelected = false;

  void _handlePenChanged(bool isSelected) {
    setState(() {
      _penSelected = isSelected;
    });
  }

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      content: ScaffoldPage(
        padding: EdgeInsets.zero,
        content: Container(
          color: FluentTheme.of(context).micaBackgroundColor,
          child: Center(
            child: PaintingBoard(
              isPenActive: _penSelected,
              onPenChanged: _handlePenChanged,
            ),
          ),
        ),
      ),
    );
  }
}
