import 'package:flutter/foundation.dart';

/// Service to manage ambient background music state across the patient app.
class BackgroundMusicService extends ChangeNotifier {
  static final BackgroundMusicService instance = BackgroundMusicService._internal();

  BackgroundMusicService._internal();
  factory BackgroundMusicService() => instance;

  bool _isPlaying = false;
  bool _isMuted = false;

  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;

  /// Starts background music playback when user enters the home screen.
  void start() {
    if (!_isPlaying) {
      _isPlaying = true;
      notifyListeners();
    }
  }

  /// Stops background music playback.
  void stop() {
    if (_isPlaying) {
      _isPlaying = false;
      notifyListeners();
    }
  }

  /// Toggles mute on/off.
  void toggleMute() {
    _isMuted = !_isMuted;
    notifyListeners();
  }

  /// Explicitly sets mute state.
  void setMuted(bool muted) {
    if (_isMuted != muted) {
      _isMuted = muted;
      notifyListeners();
    }
  }
}
