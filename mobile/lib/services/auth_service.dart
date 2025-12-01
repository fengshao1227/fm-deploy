import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/user.dart';
import 'api_service.dart';

/// 认证服务
class AuthService {
  final ApiService _api = ApiService();

  /// 登录
  Future<ApiResponse<LoginData>> login(String username, String password) async {
    try {
      final response = await _api.post(
        ApiConfig.authLogin,
        data: {
          'username': username,
          'password': password,
        },
      );

      return ApiResponse<LoginData>(
        success: response.data['success'] ?? false,
        data: response.data['success'] == true
            ? LoginData.fromJson(response.data['data'])
            : null,
        message: response.data['message'],
        error: response.data['error'],
      );
    } catch (e) {
      return ApiResponse<LoginData>(
        success: false,
        error: ApiService.getErrorMessage(e),
      );
    }
  }

  /// 获取当前用户信息
  Future<ApiResponse<User>> getCurrentUser() async {
    try {
      final response = await _api.get(ApiConfig.authMe);

      return ApiResponse<User>(
        success: response.data['success'] ?? false,
        data: response.data['success'] == true
            ? User.fromJson(response.data['data'])
            : null,
        error: response.data['error'],
      );
    } catch (e) {
      return ApiResponse<User>(
        success: false,
        error: ApiService.getErrorMessage(e),
      );
    }
  }

  /// 修改密码
  Future<ApiResponse<void>> changePassword(
    String oldPassword,
    String newPassword,
  ) async {
    try {
      final response = await _api.post(
        ApiConfig.authChangePassword,
        data: {
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        },
      );

      return ApiResponse<void>(
        success: response.data['success'] ?? false,
        message: response.data['message'],
        error: response.data['error'],
      );
    } catch (e) {
      return ApiResponse<void>(
        success: false,
        error: ApiService.getErrorMessage(e),
      );
    }
  }
}
