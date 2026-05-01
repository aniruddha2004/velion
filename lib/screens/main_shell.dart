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
  bool _initialShareProcessed = false;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
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
    try {
      // Handle sharing while app is running (warm start / app in memory)
      _shareSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
        (List<SharedMediaFile> files) {
          if (files.isNotEmpty && mounted) {
            _processSharedFiles(files);
          }
        },
        onError: (err) {
          debugPrint('Share receiver stream error: $err');
          _showErrorSnackBar('Share receiver error: $err');
        },
      );

      // Handle sharing when app is opened from share sheet (cold start)
      if (!_initialShareProcessed) {
        ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> files) {
          if (files.isNotEmpty && mounted) {
            _processSharedFiles(files);
            ReceiveSharingIntent.instance.reset();
          }
          _initialShareProcessed = true;
        }).catchError((err) {
          debugPrint('getInitialMedia error: $err');
          _initialShareProcessed = true;
        });
      }
    } catch (e) {
      debugPrint('Share receiver init error: $e');
      _showErrorSnackBar('Failed to initialize share receiver: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, maxLines: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFFF5252),
        ),
      );
    }
  }

  void _processSharedFiles(List<SharedMediaFile> files) {
    // Log all received files for debugging
    debugPrint('=== SHARE RECEIVED ===');
    debugPrint('Files count: ${files.length}');
    for (var i = 0; i < files.length; i++) {
      debugPrint('File $i: type=${files[i].type}, path="${files[i].path}"');
    }
    
    // First, check all files for share.google URLs
    for (final file in files) {
      final path = file.path;
      
      // Check if path contains share.google URL
      if (path.contains('share.google')) {
        debugPrint('Found share.google in path');
        final url = _extractUrlFromText(path);
        if (url != null) {
          _handleSharedUrl(url);
          return;
        }
      }
      
      // Check for any http URL in path
      if (path.startsWith('http')) {
        debugPrint('Found HTTP URL in path');
        _handleSharedUrl(path);
        return;
      }
    }
    
    // Then process by type
    for (final file in files) {
      if (file.type == SharedMediaType.url) {
        debugPrint('Processing as URL type');
        _handleSharedUrl(file.path);
        return;
      } else if (file.type == SharedMediaType.text) {
        debugPrint('Processing as text type');
        _handleSharedText(file.path);
        return;
      }
    }
  }
  
  String? _extractUrlFromText(String text) {
    // Try to find any URL in the text
    final patterns = [
      RegExp(r'https?://[^\s<>"\)\]\n]+', caseSensitive: false),
      RegExp(r'share\.google/[^\s<>"\)\]\n]+', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        var url = match.group(0)!;
        if (!url.startsWith('http')) {
          url = 'https://$url';
        }
        return url;
      }
    }
    return null;
  }

  void _handleSharedText(String text) {
    debugPrint('Handling shared text: "${text.substring(0, text.length.clamp(0, 100))}..."');
    
    final url = _extractUrlFromText(text);
    if (url != null) {
      debugPrint('Extracted URL: $url');
      _handleSharedUrl(url);
    } else {
      debugPrint('No URL found in text');
    }
  }

  void _handleSharedUrl(String url) async {
    debugPrint('Handling shared URL: $url');
    
    // Switch to News tab and pop to root
    setState(() {
      _currentIndex = 1;
    });
    
    // Pop any routes in News tab to show the list
    _navigatorKeys[1].currentState?.popUntil((route) => route.isFirst);

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

  void _onTabTapped(int index) {
    // If tapping the current tab, pop to root of that tab
    if (_currentIndex == index) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildNavigator(0, const DashboardScreen()),
          _buildNavigator(1, const HomeScreen()),
          _buildNavigator(2, const DiscoverScreen()),
          _buildNavigator(3, const SettingsScreen()),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF1E1E38), width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
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

  Widget _buildNavigator(int index, Widget screen) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => screen,
          settings: settings,
        );
      },
    );
  }
}
