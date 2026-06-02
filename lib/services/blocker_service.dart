import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_timer_state.dart';

const _kDefaultAccessMinutes = 60;
const _kWaitSeconds = 600; // 10-minute mandatory wait

const _kKeyAccessDuration = 'access_duration_minutes';
const _kKeyCountdownEnd = 'countdown_end_ts';
const _kKeyAccessEnd = 'access_end_ts';

class BlockerService extends ChangeNotifier {
  static const _channel = MethodChannel('com.takeitSlow/blocker');

  final SharedPreferences _prefs;

  BlockerPhase _phase = BlockerPhase.unauthorized;
  int _countdownSecondsLeft = _kWaitSeconds;
  int _accessSecondsLeft = 0;
  int _accessDurationMinutes;

  BlockerPhase get phase => _phase;
  int get countdownSecondsLeft => _countdownSecondsLeft;
  int get accessSecondsLeft => _accessSecondsLeft;
  int get accessDurationMinutes => _accessDurationMinutes;

  Timer? _ticker;

  BlockerService(this._prefs)
      : _accessDurationMinutes =
            _prefs.getInt(_kKeyAccessDuration) ?? _kDefaultAccessMinutes {
    _channel.setMethodCallHandler(_onNativeCall);
    _restorePersistedState();
    _checkAuthorization();
  }

  // ─── Native call handler ───────────────────────────────────────────────────

  Future<void> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'youtubeDetected':
        // DeviceActivityMonitor extension detected YouTube usage.
        if (_phase == BlockerPhase.idle) _beginCountdown();
        break;
    }
  }

  // ─── Authorization ─────────────────────────────────────────────────────────

  Future<void> _checkAuthorization() async {
    try {
      final authorized =
          await _channel.invokeMethod<bool>('checkAuthorization') ?? false;
      if (authorized && _phase == BlockerPhase.unauthorized) {
        _phase = BlockerPhase.idle;
        notifyListeners();
      } else if (!authorized) {
        _phase = BlockerPhase.unauthorized;
        notifyListeners();
      }
    } on PlatformException {
      _phase = BlockerPhase.unauthorized;
      notifyListeners();
    }
  }

  Future<bool> requestAuthorization() async {
    try {
      final ok =
          await _channel.invokeMethod<bool>('requestAuthorization') ?? false;
      if (ok) {
        _phase = BlockerPhase.idle;
        notifyListeners();
        await _blockNow();
      }
      return ok;
    } on PlatformException {
      return false;
    }
  }

  Future<void> showAppPicker() async {
    try {
      await _channel.invokeMethod('showAppPicker');
    } on PlatformException catch (e) {
      debugPrint('showAppPicker error: $e');
    }
  }

  // ─── State restoration ─────────────────────────────────────────────────────

  void _restorePersistedState() {
    final now = DateTime.now().millisecondsSinceEpoch;

    final accessEnd = _prefs.getInt(_kKeyAccessEnd);
    if (accessEnd != null && accessEnd > now) {
      _accessSecondsLeft = ((accessEnd - now) / 1000).ceil();
      _phase = BlockerPhase.accessible;
      _startTicker();
      return;
    }

    final countdownEnd = _prefs.getInt(_kKeyCountdownEnd);
    if (countdownEnd != null && countdownEnd > now) {
      _countdownSecondsLeft = ((countdownEnd - now) / 1000).ceil();
      _phase = BlockerPhase.countdown;
      _startTicker();
      return;
    }

    // Stale timestamps — clear them.
    _prefs.remove(_kKeyCountdownEnd);
    _prefs.remove(_kKeyAccessEnd);
  }

  // ─── Countdown (10-minute wait) ────────────────────────────────────────────

  /// Called when YouTube is first detected (or user manually triggers).
  void _beginCountdown() {
    _countdownSecondsLeft = _kWaitSeconds;
    final endMs = DateTime.now()
        .add(const Duration(seconds: _kWaitSeconds))
        .millisecondsSinceEpoch;
    _prefs.setInt(_kKeyCountdownEnd, endMs);
    _phase = BlockerPhase.countdown;
    notifyListeners();
    _startTicker();
  }

  /// Public trigger for the manual "Start my wait" button in idle state.
  void triggerManualCountdown() {
    if (_phase == BlockerPhase.idle) _beginCountdown();
  }

  // ─── Access window ─────────────────────────────────────────────────────────

  void _beginAccessWindow() {
    _prefs.remove(_kKeyCountdownEnd);
    _accessSecondsLeft = _accessDurationMinutes * 60;
    final endMs = DateTime.now()
        .add(Duration(minutes: _accessDurationMinutes))
        .millisecondsSinceEpoch;
    _prefs.setInt(_kKeyAccessEnd, endMs);
    _phase = BlockerPhase.accessible;
    notifyListeners();
    _unblockNow();
  }

  void _endAccessWindow() {
    _prefs.remove(_kKeyAccessEnd);
    _phase = BlockerPhase.idle;
    notifyListeners();
    _blockNow();
  }

  // ─── Ticker ────────────────────────────────────────────────────────────────

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    switch (_phase) {
      case BlockerPhase.countdown:
        if (_countdownSecondsLeft > 0) {
          _countdownSecondsLeft--;
          notifyListeners();
        } else {
          _ticker?.cancel();
          _beginAccessWindow();
        }
        break;

      case BlockerPhase.accessible:
        if (_accessSecondsLeft > 0) {
          _accessSecondsLeft--;
          notifyListeners();
        } else {
          _ticker?.cancel();
          _endAccessWindow();
        }
        break;

      default:
        _ticker?.cancel();
    }
  }

  // ─── Settings ──────────────────────────────────────────────────────────────

  void setAccessDuration(int minutes) {
    _accessDurationMinutes = minutes.clamp(5, 480);
    _prefs.setInt(_kKeyAccessDuration, _accessDurationMinutes);
    notifyListeners();
  }

  // ─── Native bridge ─────────────────────────────────────────────────────────

  Future<void> _blockNow() async {
    try {
      await _channel.invokeMethod('blockApps');
    } on PlatformException catch (e) {
      debugPrint('blockApps error: $e');
    }
  }

  Future<void> _unblockNow() async {
    try {
      await _channel.invokeMethod('unblockApps');
    } on PlatformException catch (e) {
      debugPrint('unblockApps error: $e');
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String formatSeconds(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
