import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/voice_provider.dart';
import '../services/voice_navigation_handler.dart';

/// Persistent voice overlay that stays on screen when voice mode is active
/// Shows a minimized indicator and handles continuous listening
class PersistentVoiceOverlay extends ConsumerStatefulWidget {
  const PersistentVoiceOverlay({super.key});

  @override
  ConsumerState<PersistentVoiceOverlay> createState() => _PersistentVoiceOverlayState();
}

class _PersistentVoiceOverlayState extends ConsumerState<PersistentVoiceOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceProvider);

    // Only show when voice is active (listening, processing, or navigating)
    if (voiceState.state == VoiceState.idle && !_isExpanded) {
      return const SizedBox.shrink();
    }

    // Start/stop pulse animation based on listening state
    if (voiceState.state == VoiceState.listening) {
      _pulseController.repeat();
    } else {
      _pulseController.stop();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      right: 16,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: voiceState.state == VoiceState.listening
                        ? [const Color(0xFFFF5252), const Color(0xFFFF7B7B)]
                        : [const Color(0xFF4ECDC4), const Color(0xFF44B09E)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (voiceState.state == VoiceState.listening
                              ? const Color(0xFFFF5252)
                              : const Color(0xFF4ECDC4))
                          .withOpacity(0.3 + (_pulseController.value * 0.2)),
                      blurRadius: 12 + (_pulseController.value * 8),
                      spreadRadius: 2 + (_pulseController.value * 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mic icon with animation
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: voiceState.state == VoiceState.listening
                          ? const Icon(Icons.mic, color: Colors.white, size: 20)
                          : voiceState.state == VoiceState.processing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.mic_none, color: Colors.white, size: 20),
                    ),
                    // Expanded content
                    if (_isExpanded) ...[
                      const SizedBox(width: 8),
                      Text(
                        voiceState.statusMessage.isNotEmpty
                            ? voiceState.statusMessage
                            : 'Voice Mode Active',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Close button
                      GestureDetector(
                        onTap: () {
                          ref.read(voiceProvider.notifier).reset();
                          setState(() => _isExpanded = false);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
