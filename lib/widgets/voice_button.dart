import 'package:flutter/material.dart';
import 'voice_overlay.dart';

/// Standardized voice button used across all screens.
/// Matches Dashboard specifications: 44x44, teal gradient, top-right placement.
class VoiceButton extends StatelessWidget {
  final double size;
  final double iconSize;
  final EdgeInsets padding;

  const VoiceButton({
    super.key,
    this.size = 44.0,
    this.iconSize = 22.0,
    this.padding = const EdgeInsets.all(10.0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4ECDC4), Color(0xFF44B09E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4ECDC4).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () => _showVoiceOverlay(context),
        child: Icon(
          Icons.mic,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
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
