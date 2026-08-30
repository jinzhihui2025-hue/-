import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'pages/home_page.dart';
import 'pages/stats_page.dart';
import 'pages/history_page.dart';
import 'pages/settings_page.dart';
import 'widgets/ios_ui.dart';

void main() => runApp(const MiaoxinApp());

class MiaoxinApp extends StatelessWidget {
  const MiaoxinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: '计件助手',
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: kIosBlue,
        scaffoldBackgroundColor: kIosBg,
        barBackgroundColor: CupertinoColors.white,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final CupertinoTabController _controller =
      CupertinoTabController(initialIndex: widget.initialIndex);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomePage(),
      const StatsPage(),
      const HistoryPage(),
      const SettingsPage(),
    ];
    return CupertinoTabScaffold(
      controller: _controller,
      tabBar: CupertinoTabBar(
        backgroundColor: CupertinoColors.white,
        activeColor: kIosBlue,
        inactiveColor: kIosSecondary,
        border: const Border(top: BorderSide(color: kIosSeparator, width: 0.5)),
        iconSize: 23,
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.house_fill), label: '首页'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.chart_bar_fill), label: '统计'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.calendar_today), label: '历史'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.gear_solid), label: '设置'),
        ],
      ),
      tabBuilder: (context, index) => CupertinoTabView(builder: (_) => pages[index]),
    );
  }
}
