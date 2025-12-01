import 'package:shared_preferences/shared_preferences.dart';

/// 本地存储工具类
class StorageUtil {
  static SharedPreferences? _prefs;

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_info';

  /// 初始化
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 保存 Token
  static Future<bool> saveToken(String token) async {
    return await _prefs?.setString(_tokenKey, token) ?? false;
  }

  /// 获取 Token
  static String? getToken() {
    return _prefs?.getString(_tokenKey);
  }

  /// 删除 Token
  static Future<bool> removeToken() async {
    return await _prefs?.remove(_tokenKey) ?? false;
  }

  /// 保存用户信息（JSON 字符串）
  static Future<bool> saveUser(String userJson) async {
    return await _prefs?.setString(_userKey, userJson) ?? false;
  }

  /// 获取用户信息
  static String? getUser() {
    return _prefs?.getString(_userKey);
  }

  /// 删除用户信息
  static Future<bool> removeUser() async {
    return await _prefs?.remove(_userKey) ?? false;
  }

  /// 清除所有数据
  static Future<bool> clear() async {
    return await _prefs?.clear() ?? false;
  }

  /// 检查是否已登录
  static bool isLoggedIn() {
    final token = getToken();
    return token != null && token.isNotEmpty;
  }
}
