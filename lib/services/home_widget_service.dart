import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import '../providers/voice_provider.dart';
import '../services/voice_navigation_handler.dart';
import '../screens/main_shell.dart';

/// Service for handling home screen widget interactions
class HomeWidgetService {
  static const String appGroupId = 'com.yourapp.velion';
  static const String androidWidgetName = 'HomeWidgetPlugin';
  
  /// Initialize home widget service
  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(appGroupId);
  }

  /// Check if app was launched from widget
  static Future<bool> wasLaunchedFromWidget() async {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    return uri != null;
  }

  /// Setup widget click listener
  static void setupWidgetListener(BuildContext context, WidgetRef ref) {
    HomeWidget.widgetClicked.listen((uri) {
      if (uri != null) {
        _handleWidgetClick(context, ref);
      }
    });
  }

  /// Handle widget click - activate voice mode
  static void _handleWidgetClick(BuildContext context, WidgetRef ref) {
    // Activate persistent voice mode
    ref.read(voiceProvider.notifier).togglePersistentMode();
  }

  /// Update widget data (optional - for dynamic widget content)
  static Future<void> updateWidget({String? status}) async {
    try {
      await HomeWidget.saveWidgetData<String>('status', status ?? 'Tap to speak');
      await HomeWidget.updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
      );
    } catch (e) {
      debugPrint('Widget update failed: $e');
    }
  }
}
