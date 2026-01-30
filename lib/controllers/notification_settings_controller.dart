/// Push notification settings controller
///
/// Handles all business logic for notification settings including:
/// - UnifiedPush registration and management
/// - Matrix push rules configuration
/// - Pusher management (registered devices)
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/config/setting_keys.dart';
import 'package:monochat/utils/background_push.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unifiedpush/unifiedpush.dart';

/// State for push notification settings
class NotificationSettingsState {
  final bool isLoading;
  final String? errorMessage;

  // UnifiedPush status
  final String? upDistributor;
  final String? upEndpoint;
  final bool upRegistered;
  final List<String> availableDistributors;

  // Matrix pushers (registered devices)
  final List<Pusher> pushers;
  final bool isLoadingPushers;

  // Push rules
  final PushRuleSet? pushRules;
  final bool isUpdatingRule;

  const NotificationSettingsState({
    this.isLoading = false,
    this.errorMessage,
    this.upDistributor,
    this.upEndpoint,
    this.upRegistered = false,
    this.availableDistributors = const [],
    this.pushers = const [],
    this.isLoadingPushers = false,
    this.pushRules,
    this.isUpdatingRule = false,
  });

  NotificationSettingsState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? upDistributor,
    String? upEndpoint,
    bool? upRegistered,
    List<String>? availableDistributors,
    List<Pusher>? pushers,
    bool? isLoadingPushers,
    PushRuleSet? pushRules,
    bool? isUpdatingRule,
  }) {
    return NotificationSettingsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      upDistributor: upDistributor ?? this.upDistributor,
      upEndpoint: upEndpoint ?? this.upEndpoint,
      upRegistered: upRegistered ?? this.upRegistered,
      availableDistributors:
          availableDistributors ?? this.availableDistributors,
      pushers: pushers ?? this.pushers,
      isLoadingPushers: isLoadingPushers ?? this.isLoadingPushers,
      pushRules: pushRules ?? this.pushRules,
      isUpdatingRule: isUpdatingRule ?? this.isUpdatingRule,
    );
  }
}

/// Controller for notification settings
class NotificationSettingsController extends ChangeNotifier {
  final Client _client;
  NotificationSettingsState _state = const NotificationSettingsState();
  StreamSubscription<SyncUpdate>? _syncSubscription;

  NotificationSettingsController(this._client) {
    _init();
  }

  NotificationSettingsState get state => _state;
  Client get client => _client;

  void _init() {
    _loadInitialData();
    _listenToPushRulesUpdates();
  }

  void _listenToPushRulesUpdates() {
    _syncSubscription = _client.onSync.stream
        .where(
          (syncUpdate) =>
              syncUpdate.accountData?.any(
                (accountData) => accountData.type == 'm.push_rules',
              ) ??
              false,
        )
        .listen((_) {
          _state = _state.copyWith(pushRules: _client.globalPushRules);
          notifyListeners();
        });
  }

  Future<void> _loadInitialData() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    try {
      // Load UnifiedPush status
      final distributor = await UnifiedPush.getDistributor();
      final distributors = await UnifiedPush.getDistributors();
      final prefs = await SharedPreferences.getInstance();
      final endpoint = prefs.getString(SettingKeys.unifiedPushEndpoint);
      final registered =
          prefs.getBool(SettingKeys.unifiedPushRegistered) ?? false;

      // Load push rules
      final pushRules = _client.globalPushRules;

      _state = _state.copyWith(
        isLoading: false,
        upDistributor: distributor,
        upEndpoint: endpoint,
        upRegistered: registered,
        availableDistributors: distributors,
        pushRules: pushRules,
      );
      notifyListeners();

      // Load pushers in background
      await loadPushers();
    } catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.toString());
      notifyListeners();
    }
  }

  /// Reload all data
  Future<void> refresh() async {
    await _loadInitialData();
  }

  /// Load registered pushers (devices with push notifications)
  Future<void> loadPushers() async {
    _state = _state.copyWith(isLoadingPushers: true);
    notifyListeners();

    try {
      final pushers = await _client.getPushers() ?? [];
      _state = _state.copyWith(isLoadingPushers: false, pushers: pushers);
    } catch (e) {
      _state = _state.copyWith(
        isLoadingPushers: false,
        errorMessage: 'Failed to load pushers: $e',
      );
    }
    notifyListeners();
  }

  /// Register with UnifiedPush
  Future<void> registerUnifiedPush() async {
    final backgroundPush = BackgroundPush.clientOnly(_client);
    await backgroundPush.setupUp();
    await refresh();
  }

  /// Unregister from UnifiedPush
  Future<void> unregisterUnifiedPush() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    try {
      await UnifiedPush.unregister();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(SettingKeys.unifiedPushEndpoint);
      await prefs.setBool(SettingKeys.unifiedPushRegistered, false);

      _state = _state.copyWith(
        isLoading: false,
        upRegistered: false,
        upEndpoint: null,
        upDistributor: null,
      );
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to unregister: $e',
      );
    }
    notifyListeners();
  }

  /// Delete a pusher (unregister device from push notifications)
  Future<bool> deletePusher(Pusher pusher) async {
    try {
      await _client.deletePusher(pusher);
      await loadPushers();
      return true;
    } catch (e) {
      _state = _state.copyWith(errorMessage: 'Failed to delete pusher: $e');
      notifyListeners();
      return false;
    }
  }

  /// Toggle a push rule on/off
  Future<bool> togglePushRule(PushRuleKind kind, PushRule rule) async {
    _state = _state.copyWith(isUpdatingRule: true);
    notifyListeners();

    try {
      await _client.setPushRuleEnabled(kind, rule.ruleId, !rule.enabled);
      // Wait for sync update to refresh the rules
      await _client.onSync.stream
          .where(
            (syncUpdate) =>
                syncUpdate.accountData?.any(
                  (accountData) => accountData.type == 'm.push_rules',
                ) ??
                false,
          )
          .first
          .timeout(const Duration(seconds: 10));

      _state = _state.copyWith(
        isUpdatingRule: false,
        pushRules: _client.globalPushRules,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _state = _state.copyWith(
        isUpdatingRule: false,
        errorMessage: 'Failed to update rule: $e',
      );
      notifyListeners();
      return false;
    }
  }

  /// Check if all notifications are muted (master rule)
  bool get allNotificationsMuted => _client.allPushNotificationsMuted;

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }
}
