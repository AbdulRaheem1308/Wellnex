import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../../../services/api_service.dart';
import '../../../../services/storage_service.dart';
import '../../../../core/router/app_router.dart';

import '../../domain/models/user_model.dart';
import '../../services/social_auth_service.dart';
import '../../../../core/services/push_notification_service.dart';

/// Auth state
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final Map<String, dynamic>? user;
  final String? error;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    Map<String, dynamic>? user,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      error: error,
    );
  }
}

/// Auth Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(apiServiceProvider),
    ref.watch(socialAuthServiceProvider),
    ref.watch(pushNotificationServiceProvider),
    ref.watch(appRouterProvider),
  );
});

/// Current User Provider
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authProvider);
  if (authState.user == null) return null;
  return User.fromJson(authState.user!);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;
  final SocialAuthService _socialAuth;
  final PushNotificationService _pushService;
  final GoRouter _router;

  AuthNotifier(this._apiService, this._socialAuth, this._pushService, this._router)
      : super(AuthState()) {
    _apiService.onAuthFailure = logout;
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await StorageService.getAccessToken();
    final user = StorageService.getUser();
    
    if (token != null && user != null) {
      state = state.copyWith(
        isAuthenticated: true,
        user: user,
      );
    }
  }

  /// Send OTP to phone or email
  Future<void> sendOtp({String? phone, String? email}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _apiService.post('/auth/send-otp', data: {
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
      });
      
      state = state.copyWith(isLoading: false);
    } catch (e) {
      final error = ApiError.from(e);
      state = state.copyWith(isLoading: false, error: error.message);
      throw error;
    }
  }

  /// Verify OTP and login
  /// Returns true if the user is new and needs to complete profile
  Future<bool> verifyOtp({
    String? phone,
    String? email,
    required String otp,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiService.post('/auth/verify-otp', data: {
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        'otp': otp,
      });

      final data = response.data;
      
      // Save tokens
      await StorageService.saveTokens(
        accessToken: data['tokens']['accessToken'],
        refreshToken: data['tokens']['refreshToken'],
      );
      
      // Save user
      await StorageService.saveUser(data['user']);
      
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: data['user'],
      );

      // Register FCM token now that we have a valid session
      _pushService.registerTokenAfterLogin().ignore();

      return data['isNewUser'] == true;
    } catch (e) {
      final error = ApiError.from(e);
      state = state.copyWith(isLoading: false, error: error.message);
      throw error;
    }
  }



  /// Login with Social (Google/Apple) ID Token
  Future<bool> loginWithSocial(String idToken) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiService.post('/auth/social-login', data: {
        'idToken': idToken,
      });

      final data = response.data;
      
      // Save tokens
      await StorageService.saveTokens(
        accessToken: data['tokens']['accessToken'],
        refreshToken: data['tokens']['refreshToken'],
      );
      
      // Save user
      await StorageService.saveUser(data['user']);
      
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: data['user'],
      );

      // Register FCM token now that we have a valid session
      _pushService.registerTokenAfterLogin().ignore();

      return data['isNewUser'] == true;
    } catch (e) {
      final error = ApiError.from(e);
      state = state.copyWith(isLoading: false, error: error.message);
      throw error;
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      final refreshToken = await StorageService.getRefreshToken();
      if (refreshToken != null) {
        await _apiService.post('/auth/logout', data: {
          'refreshToken': refreshToken,
        });
      }
    } catch (e) {
      // Ignore logout errors
    }

    // Sign out from social logins (Google Sign-In SDK & Firebase Auth)
    try {
      await _socialAuth.signOut();
    } catch (e) {
      debugPrint('Social Sign-out error: $e');
    }

    // Clear FCM token from backend so no stale notifications are sent
    _pushService.clearTokenOnLogout().ignore();

    await StorageService.clearTokens();
    await StorageService.clearUser();
    
    state = AuthState();
    _router.go(AppRoutes.login);
  }

  /// Update user profile
  Future<void> updateProfile(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiService.put('/users/me', data: data);
      final updatedUser = response.data; // Assuming backend returns the full user object
      
      await StorageService.saveUser(updatedUser);
      
      state = state.copyWith(
        isLoading: false,
        user: updatedUser,
      );
    } catch (e) {
      final error = ApiError.from(e);
      state = state.copyWith(isLoading: false, error: error.message);
      throw error;
    }
  }

  /// Update user in state
  void updateUser(Map<String, dynamic> user) {
    StorageService.saveUser(user);
    state = state.copyWith(user: user);
  }
}
