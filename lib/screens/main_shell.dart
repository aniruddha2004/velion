import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';
import 'dashboard_screen.dart';
import 'home_screen.dart';
import 'discover_screen.dart';
import 'settings_screen.dart';
import '../providers/news_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;
  StreamSubscription? _shareSubscription;
  bool _initialShareHandled = false;

  final List<Widget> _screens = const [
    DashboardScreen(),
    HomeScreen(),
    DiscoverScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initShareReceiver();
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    super.dispose();
  }

  void _initShareReceiver() {
    // Handle sharing while app is running
    _shareSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) {
        for (final file in files) {
          if (file.type == SharedMediaType.url || file.type == SharedMediaType.text) {
            _handleSharedText(file.path);
          } else if (file.path.startsWith('http')) {
            _handleSharedUrl(file.path);
          }
        }
      },
      onError: (err) {
        debugPrint('Share receiver error: $err');
      },
    );

    // Handle initial share when app is opened from share sheet
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> files) {
      if (!_initialShareHandled && files.isNotEmpty) {
        for (final file in files) {
          if (file.type == SharedMediaType.url || file.type == SharedMediaType.text) {
            _initialShareHandled = true;
            _handleSharedText(file.path);
          } else if (file.path.startsWith('http')) {
            _initialShareHandled = true;
            _handleSharedUrl(file.path);
          }
        }
      }
    });
  }

  void _handleSharedText(String text) {
    final urlRegex = RegExp(r'https?://[^\s<>"\)\]]+', caseSensitive: false);
    final match = urlRegex.firstMatch(text);
    if (match != null) {
      _handleSharedUrl(match.group(0)!);
    }
  }

  void _handleSharedUrl(String url) async {
    // Switch to News tab when receiving a shared URL
    setState(() => _currentIndex = 1);

    final notifier = ref.read(addArticleProvider.notifier);
    final article = await notifier.addArticle(url);

    if (mounted) {
      if (article != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Article added: ${article.displayTitle}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final state = ref.read(addArticleProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error ?? 'Failed to add article'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF1E1E38), width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.article_outlined),
              activeIcon: Icon(Icons.article),
              label: 'News',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Discover',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
