import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/news_article.dart';
import 'models/doc_group.dart';
import 'models/doc_document.dart';
import 'screens/main_shell.dart';
import 'services/objectbox_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: const Color(0xFF0B0D12),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  await Hive.initFlutter();
  Hive.registerAdapter(NewsArticleAdapter());
  Hive.registerAdapter(DocGroupAdapter());
  Hive.registerAdapter(DocDocumentAdapter());
  await Hive.openBox<NewsArticle>('newsArticles');
  await Hive.openBox<DocGroup>('docGroups');
  await Hive.openBox<DocDocument>('docDocuments');

  // Initialize ObjectBox
  await ObjectBoxService().store;

  runApp(const ProviderScope(child: VelionApp()));
}

class VelionApp extends StatelessWidget {
  const VelionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Velion',
      debugShowCheckedModeBanner: false,
      theme: _buildDarkTheme(),
      home: const MainShell(),
    );
  }

  ThemeData _buildDarkTheme() {
    // Brand colors from Velion logo.html (open-codesign)
    const darkBg = Color(0xFF0B0D12);            // Main background
    const cardBg = Color(0xFF16181F);             // Card surface
    const surfaceVariant = Color(0xFF1E2029);     // Input/surface variant
    const accentViolet = Color(0xFF6878FF);       // Primary accent from logo
    const accentLight = Color(0xFFF4F6FB);        // Light accent / text
    const subtitleColor = Color(0xFFA6ADBD);      // Subtitle color from logo
    const borderFaint = Color(0x14FFFFFF);         // rgba(255,255,255,0.08)

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: accentViolet,
        onPrimary: Colors.white,
        secondary: Color(0xFF3B82F6),
        onSecondary: Colors.white,
        surface: cardBg,
        onSurface: accentLight,
        surfaceVariant: surfaceVariant,
        error: Color(0xFFFF5252),
        onError: Colors.white,
        outline: Color(0xFF2A2C38),
        onSurfaceVariant: subtitleColor,
      ),
      cardTheme: CardTheme(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0B0D12),
        selectedItemColor: accentViolet,
        unselectedItemColor: Color(0xFF5A5A6A),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentViolet,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accentViolet, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: Color(0xFF5A5A7A)),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: Color(0xFFE0E0F0),
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: Color(0xFFC0C0D8),
          fontSize: 14,
          height: 1.5,
        ),
        labelLarge: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(
          color: Color(0xFF9E9EBF),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: TextStyle(
          color: Color(0xFF7A7A9A),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceVariant,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      useMaterial3: true,
    );
  }
}
