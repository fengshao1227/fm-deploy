import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/storage_util.dart';

/// 认证状态
class AuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final User? user;
  final String? error;

  AuthState({
    this.isLoading = false,
    this.isLoggedIn = false,
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    User? user,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: user ?? this.user,
      error: error,
    );
  }
}

/// 认证状态管理
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService = AuthService();

  AuthNotifier() : super(AuthState());

  /// 初始化（检查本地登录状态）
  Future<void> init() async {
    final token = StorageUtil.getToken();
    if (token != null && token.isNotEmpty) {
      ApiService().setToken(token);

      // 尝试从本地恢复用户信息
      final userJson = StorageUtil.getUser();
      if (userJson != null) {
        try {
          final user = User.fromJsonString(userJson);
          state = state.copyWith(isLoggedIn: true, user: user);
        } catch (_) {
          // 本地数据损坏，尝试从服务器获取
          await refreshUser();
        }
      } else {
        // 尝试从服务器获取用户信息
        await refreshUser();
      }
    }
  }

  /// 登录
  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    final response = await _authService.login(username, password);

    if (response.success && response.data != null) {
      final loginData = response.data!;

      // 保存 Token 和用户信息
      await StorageUtil.saveToken(loginData.token);
      await StorageUtil.saveUser(loginData.user.toJsonString());

      // 设置 API Token
      ApiService().setToken(loginData.token);

      state = AuthState(
        isLoggedIn: true,
        user: loginData.user,
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        error: response.error ?? '登录失败',
      );
      return false;
    }
  }

  /// 刷新用户信息
  Future<void> refreshUser() async {
    final response = await _authService.getCurrentUser();

    if (response.success && response.data != null) {
      await StorageUtil.saveUser(response.data!.toJsonString());
      state = state.copyWith(isLoggedIn: true, user: response.data);
    } else {
      // Token 无效，清除登录状态
      await logout();
    }
  }

  /// 修改密码
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    state = state.copyWith(isLoading: true, error: null);

    final response = await _authService.changePassword(oldPassword, newPassword);

    state = state.copyWith(isLoading: false);

    if (response.success) {
      return true;
    } else {
      state = state.copyWith(error: response.error ?? '修改密码失败');
      return false;
    }
  }

  /// 退出登录
  Future<void> logout() async {
    ApiService().clearToken();
    state = AuthState();
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// 认证状态 Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
