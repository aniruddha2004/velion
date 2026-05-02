import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/voice_command_service.dart';
import '../services/settings_service.dart';
import '../services/objectbox_service.dart';

enum VoiceState {
  idle,
  listening,
  processing,
  navigating,
  error,
}

class VoiceStateData {
  final VoiceState state;
  final String recognizedText;
  final String statusMessage;
  final String? errorMessage;
  final bool isPersistentActive;

  VoiceStateData({
    this.state = VoiceState.idle,
    this.recognizedText = '',
    this.statusMessage = '',
    this.errorMessage,
    this.isPersistentActive = false,
  });

  VoiceStateData copyWith({
    VoiceState? state,
    String? recognizedText,
    String? statusMessage,
    String? errorMessage,
    bool? isPersistentActive,
  }) {
    return VoiceStateData(
      state: state ?? this.state,
      recognizedText: recognizedText ?? this.recognizedText,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage ?? this.errorMessage,
      isPersistentActive: isPersistentActive ?? this.isPersistentActive,
    );
  }
}

class VoiceNotifier extends StateNotifier<VoiceStateData> {
  final SettingsService _settings;
  final ObjectBoxService _objectBox;
  late VoiceCommandService _voiceCommandService;
  final SpeechToText _speechToText = SpeechToText();
  
  bool _isInitialized = false;
  Completer<VoiceIntent>? _intentCompleter;

  VoiceNotifier(this._settings, this._objectBox) : super(VoiceStateData()) {
    _voiceCommandService = VoiceCommandService(_settings, _objectBox);
  }

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    // Request microphone permission
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      state = state.copyWith(
        state: VoiceState.error,
        errorMessage: 'Microphone permission denied. Please enable it in settings.',
      );
      return false;
    }

    // Initialize speech recognition
    _isInitialized = await _speechToText.initialize(
      onError: (error) {
        state = state.copyWith(
          state: VoiceState.error,
          errorMessage: 'Speech recognition error: $error',
        );
        _intentCompleter?.complete(VoiceIntent.unknown(state.recognizedText));
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _onListeningComplete();
        }
      },
    );

    return _isInitialized;
  }

  Future<VoiceIntent> listenForCommand() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        return VoiceIntent.unknown('');
      }
    }

    _intentCompleter = Completer<VoiceIntent>();
    
    state = state.copyWith(
      state: VoiceState.listening,
      statusMessage: 'Listening...',
      recognizedText: '',
      errorMessage: null,
    );

    await _speechToText.listen(
      onResult: (result) {
        state = state.copyWith(
          recognizedText: result.recognizedWords,
        );
        
        // If final result, process it
        if (result.finalResult) {
          _onListeningComplete();
        }
      },
      listenFor: const Duration(seconds: 30),      // Increased from 10s to 30s
      pauseFor: const Duration(seconds: 5),         // Increased from 3s to 5s - allows longer pauses between words
      localeId: null,
      cancelOnError: false,                         // Don't cancel on error - keep trying
      partialResults: true,
    );

    return _intentCompleter!.future;
  }

  void _onListeningComplete() async {
    if (state.recognizedText.isEmpty) {
      state = state.copyWith(
        state: VoiceState.idle,
        statusMessage: '',
      );
      _intentCompleter?.complete(VoiceIntent.unknown(''));
      return;
    }

    state = state.copyWith(
      state: VoiceState.processing,
      statusMessage: 'Understanding...',
    );

    // Parse the command using AI
    final intent = await _voiceCommandService.parseCommand(state.recognizedText);
    
    _intentCompleter?.complete(intent);
    
    if (intent.type != VoiceIntentType.unknown) {
      state = state.copyWith(
        state: VoiceState.navigating,
        statusMessage: 'Taking you there...',
      );
    } else {
      state = state.copyWith(
        state: VoiceState.idle,
        statusMessage: 'Didn\'t understand. Try again.',
      );
    }
  }

  void stopListening() {
    _speechToText.stop();
    state = state.copyWith(
      state: VoiceState.idle,
      statusMessage: '',
    );
  }

  void reset() {
    _speechToText.stop();
    state = VoiceStateData();
  }

  void togglePersistentMode() {
    final newState = !state.isPersistentActive;
    state = state.copyWith(
      isPersistentActive: newState,
      state: newState ? VoiceState.listening : VoiceState.idle,
      statusMessage: newState ? 'Voice mode active' : '',
    );
    
    if (newState) {
      _startContinuousListening();
    } else {
      _speechToText.stop();
    }
  }

  Future<void> _startContinuousListening() async {
    if (!state.isPersistentActive) return;
    
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        state = state.copyWith(isPersistentActive: false);
        return;
      }
    }

    // Listen for a command
    final intent = await listenForCommand();
    
    if (intent.type != VoiceIntentType.unknown && state.isPersistentActive) {
      // Execute the intent
      state = state.copyWith(statusMessage: 'Processing...');
      
      // Small delay to show processing state
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Restart listening if still in persistent mode
      if (state.isPersistentActive) {
        state = state.copyWith(
          state: VoiceState.listening,
          statusMessage: 'Listening...',
          recognizedText: '',
        );
        _startContinuousListening();
      }
    } else if (state.isPersistentActive) {
      // If unknown command, restart listening after brief pause
      await Future.delayed(const Duration(seconds: 1));
      if (state.isPersistentActive) {
        state = state.copyWith(
          state: VoiceState.listening,
          statusMessage: 'Listening...',
          recognizedText: '',
        );
        _startContinuousListening();
      }
    }
  }

  @override
  void dispose() {
    _speechToText.cancel();
    super.dispose();
  }
}

// Provider
final voiceProvider = StateNotifierProvider<VoiceNotifier, VoiceStateData>((ref) {
  final settings = ref.watch(settingsServiceProvider);
  final objectBox = ref.watch(objectBoxServiceProvider);
  return VoiceNotifier(settings, objectBox);
});

// Services providers (need to add these)
final settingsServiceProvider = Provider<SettingsService>((ref) => SettingsService());
final objectBoxServiceProvider = Provider<ObjectBoxService>((ref) => ObjectBoxService());
