import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/api/discourse_api_client.dart';
import 'package:lunaris/core/auth/auth_service.dart';
import 'package:lunaris/core/models/user_profile.dart';
import 'package:lunaris/core/providers/providers.dart';

class UserProfileParams {
  final String serverUrl;
  final String username;

  const UserProfileParams({required this.serverUrl, required this.username});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileParams &&
          serverUrl == other.serverUrl &&
          username == other.username;

  @override
  int get hashCode => Object.hash(serverUrl, username);
}

class UserProfileState {
  final UserProfile? profile;
  final List<UserBadge> badges;
  final List<UserAction> activity;
  final bool isLoading;
  final bool isLoadingActivity;
  final Object? error;

  const UserProfileState({
    this.profile,
    this.badges = const [],
    this.activity = const [],
    this.isLoading = true,
    this.isLoadingActivity = false,
    this.error,
  });

  UserProfileState copyWith({
    UserProfile? profile,
    List<UserBadge>? badges,
    List<UserAction>? activity,
    bool? isLoading,
    bool? isLoadingActivity,
    Object? error,
    bool clearError = false,
  }) {
    return UserProfileState(
      profile: profile ?? this.profile,
      badges: badges ?? this.badges,
      activity: activity ?? this.activity,
      isLoading: isLoading ?? this.isLoading,
      isLoadingActivity: isLoadingActivity ?? this.isLoadingActivity,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final userProfileProvider = StateNotifierProvider.family<
    UserProfileNotifier, UserProfileState, UserProfileParams>(
  (ref, params) => UserProfileNotifier(
    ref.watch(discourseApiClientProvider),
    ref.watch(authServiceProvider),
    params,
  ),
);

class UserProfileNotifier extends StateNotifier<UserProfileState> {
  final DiscourseApiClient _apiClient;
  final AuthService _authService;
  final UserProfileParams _params;

  UserProfileNotifier(this._apiClient, this._authService, this._params)
      : super(const UserProfileState()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final apiKey = await _authService.loadApiKey(_params.serverUrl);
      if (apiKey == null) {
        state = state.copyWith(isLoading: false, error: 'Not authenticated');
        return;
      }

      final results = await Future.wait([
        _apiClient.fetchUserProfile(
          _params.serverUrl,
          apiKey,
          username: _params.username,
        ),
        _apiClient.fetchUserSummary(
          _params.serverUrl,
          apiKey,
          username: _params.username,
        ),
        _apiClient.fetchUserBadges(
          _params.serverUrl,
          apiKey,
          username: _params.username,
        ),
        _apiClient.fetchUserActions(
          _params.serverUrl,
          apiKey,
          username: _params.username,
        ),
      ]);

      final profileJson = results[0] as Map<String, dynamic>;
      final summaryJson = results[1] as Map<String, dynamic>;
      final badgesJson = results[2] as List<dynamic>;
      final actionsJson = results[3] as List<dynamic>;

      final profile =
          UserProfile.fromApiJson(profileJson).withSummary(summaryJson);

      final badges =
          badgesJson
              .map((b) => UserBadge.fromApiJson(b as Map<String, dynamic>))
              .toList();

      final activity =
          actionsJson
              .map((a) => UserAction.fromApiJson(a as Map<String, dynamic>))
              .toList();

      state = UserProfileState(
        profile: profile,
        badges: badges,
        activity: activity,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> refresh() async {
    state = const UserProfileState();
    await _load();
  }

  Future<void> loadMoreActivity() async {
    if (state.isLoadingActivity || state.activity.isEmpty) return;
    state = state.copyWith(isLoadingActivity: true);
    try {
      final apiKey = await _authService.loadApiKey(_params.serverUrl);
      if (apiKey == null) {
        state = state.copyWith(isLoadingActivity: false);
        return;
      }

      final actions = await _apiClient.fetchUserActions(
        _params.serverUrl,
        apiKey,
        username: _params.username,
        offset: state.activity.length,
      );

      final newActions =
          actions
              .map((a) => UserAction.fromApiJson(a as Map<String, dynamic>))
              .toList();

      state = state.copyWith(
        activity: [...state.activity, ...newActions],
        isLoadingActivity: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingActivity: false, error: e);
    }
  }
}
