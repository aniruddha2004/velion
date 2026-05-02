import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/voice_provider.dart';
import 'voice_overlay.dart';

/// Standardized voice button used across all screens.
/// Matches Dashboard specifications: 44x44, teal gradient, top-right placement.
/// Supports both modal mode (default) and toggle mode for persistent listening.
class VoiceButton extends ConsumerWidget {
  final double size;
  final double iconSize;
  final EdgeInsets padding;
  final bool useToggleMode;

  const VoiceButton({
    super.key,
    this.size = 44.0,
    this.iconSize = 22.0,
    this.padding = const EdgeInsets.all(10.0),
    this.useToggleMode = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceProvider);
    final isActive = voiceState.isPersistentActive || voiceState.state == VoiceState.listening;
    
    return Container(
      width: size,
      height: size,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [const Color(0xFFFF5252), const Color(0xFFFF7B7B)]
              : [const Color(0xFF4ECDC4), const Color(0xFF44B09E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14.0),
        boxShadow: [
          BoxShadow(
            color: (isActive
                    ? const Color(0xFFFF5252)
                    : const Color(0xFF4ECDC4))
                .withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () => useToggleMode
            ? _toggleVoiceMode(ref)
            : _showVoiceOverlay(context),
        child: Icon(
          isActive ? Icons.mic : Icons.mic_none,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }

  void _toggleVoiceMode(WidgetRef ref) {
    ref.read(voiceProvider.notifier).togglePersistentMode();
  }

  void _showVoiceOverlay(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => VoiceOverlay(
        onClose: () => Navigator.pop(dialogContext),
      ),
    );
  }
}
