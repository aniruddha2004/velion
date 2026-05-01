import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/voice_provider.dart';
import '../services/voice_navigation_handler.dart';

class VoiceOverlay extends ConsumerStatefulWidget {
  final VoidCallback? onClose;

  const VoiceOverlay({super.key, this.onClose});

  @override
  ConsumerState<VoiceOverlay> createState() => _VoiceOverlayState();
}

class _VoiceOverlayState extends ConsumerState<VoiceOverlay> {
  @override
  void initState() {
    super.initState();
    // Start listening when overlay opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startListening();
    });
  }

  Future<void> _startListening() async {
    final notifier = ref.read(voiceProvider.notifier);
    
    // Initialize first
    final initialized = await notifier.initialize();
    if (!initialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission required for voice commands'),
            backgroundColor: Color(0xFFFF5252),
          ),
        );
        widget.onClose?.call();
      }
      return;
    }

    // Start listening
    final intent = await notifier.listenForCommand();
    
    if (mounted && intent.type.toString() != 'VoiceIntentType.unknown') {
      // Execute navigation
      final navigator = VoiceNavigationHandler(ref, context);
      await navigator.executeIntent(intent);
      
      // Close overlay after navigation
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        widget.onClose?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceProvider);

    return Material(
      color: Colors.black.withOpacity(0.9),
      child: SafeArea(
        child: Column(
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: IconButton(
                  onPressed: () {
                    ref.read(voiceProvider.notifier).reset();
                    widget.onClose?.call();
                  },
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
              ),
            ),

            const Spacer(),

            // Main voice UI
            _VoiceVisualizer(state: voiceState),

            const SizedBox(height: 40),

            // Recognized text display
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF16181F),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2A2C38)),
              ),
              child: Column(
                children: [
                  Text(
                    voiceState.recognizedText.isEmpty
                        ? 'Say something...'
                        : voiceState.recognizedText,
                    style: TextStyle(
                      color: voiceState.recognizedText.isEmpty
                          ? const Color(0xFF5A5A6A)
                          : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (voiceState.statusMessage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      voiceState.statusMessage,
                      style: TextStyle(
                        color: _getStatusColor(voiceState.state),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Spacer(),

            // Instructions
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Try saying:\n"Show me my Aadhaar card" or "Search news about AI"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF5A5A6A),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(VoiceState state) {
    switch (state) {
      case VoiceState.listening:
        return const Color(0xFF4ECDC4);
      case VoiceState.processing:
        return const Color(0xFF6878FF);
      case VoiceState.navigating:
        return Colors.green;
      case VoiceState.error:
        return const Color(0xFFFF5252);
      default:
        return const Color(0xFF5A5A6A);
    }
  }
}

class _VoiceVisualizer extends StatefulWidget {
  final VoiceStateData state;

  const _VoiceVisualizer({required this.state});

  @override
  State<_VoiceVisualizer> createState() => _VoiceVisualizerState();
}

class _VoiceVisualizerState extends State<_VoiceVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isListening = widget.state.state == VoiceState.listening;
    final isProcessing = widget.state.state == VoiceState.processing ||
        widget.state.state == VoiceState.navigating;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer ripple rings
            if (isListening) ...[
              _buildRippleRing(0.0, 1.0),
              _buildRippleRing(0.33, 0.8),
              _buildRippleRing(0.66, 0.6),
            ],

            // Glow effect
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _getGlowColor().withOpacity(0.3),
                    _getGlowColor().withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            // Main mic button
            GestureDetector(
              onTap: () {
                if (isListening) {
                  // Stop listening handled by provider
                }
              },
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _getButtonColors(),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getGlowColor().withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  _getIcon(),
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),

            // Processing spinner
            if (isProcessing)
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color(0xFF6878FF),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildRippleRing(double delay, double opacity) {
    final animationValue = (_controller.value + delay) % 1.0;
    final scale = 1.0 + (animationValue * 0.5);
    final fadeOut = 1.0 - animationValue;

    return Transform.scale(
      scale: scale,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF4ECDC4).withOpacity(opacity * fadeOut * 0.5),
            width: 2,
          ),
        ),
      ),
    );
  }

  List<Color> _getButtonColors() {
    switch (widget.state.state) {
      case VoiceState.listening:
        return [const Color(0xFFFF5252), const Color(0xFFFF7B7B)];
      case VoiceState.processing:
      case VoiceState.navigating:
        return [const Color(0xFF6878FF), const Color(0xFF3B82F6)];
      case VoiceState.error:
        return [const Color(0xFFFF5252), const Color(0xFFD32F2F)];
      default:
        return [const Color(0xFF4ECDC4), const Color(0xFF44B09E)];
    }
  }

  Color _getGlowColor() {
    switch (widget.state.state) {
      case VoiceState.listening:
        return const Color(0xFFFF5252);
      case VoiceState.processing:
      case VoiceState.navigating:
        return const Color(0xFF6878FF);
      case VoiceState.error:
        return const Color(0xFFFF5252);
      default:
        return const Color(0xFF4ECDC4);
    }
  }

  IconData _getIcon() {
    switch (widget.state.state) {
      case VoiceState.listening:
        return Icons.stop;
      case VoiceState.processing:
        return Icons.psychology;
      case VoiceState.navigating:
        return Icons.navigation;
      case VoiceState.error:
        return Icons.error_outline;
      default:
        return Icons.mic;
    }
  }
}
