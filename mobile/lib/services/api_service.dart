import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../utils/storage_util.dart';

/// API 服务封装
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;
  String? _token;

  // 401 回调（用于跳转登录）
  Function? onUnauthorized;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // 添加拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // 注入 Token
        if (_token != null && _token!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        if (kDebugMode) {
          print('REQUEST[${options.method}] => PATH: ${options.path}');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          print('RESPONSE[${response.statusCode}] => DATA: ${response.data}');
        }
        return handler.next(response);
      },
      onError: (error, handler) {
        if (kDebugMode) {
          print('ERROR[${error.response?.statusCode}] => MESSAGE: ${error.message}');
        }
        // 处理 401 未授权
        if (error.response?.statusCode == 401) {
          clearToken();
          onUnauthorized?.call();
        }
        return handler.next(error);
      },
    ));
  }

  /// 设置 Token
  void setToken(String token) {
    _token = token;
  }

  /// 清除 Token
  void clearToken() {
    _token = null;
    StorageUtil.removeToken();
    StorageUtil.removeUser();
  }

  /// 从本地恢复 Token
  void restoreToken() {
    _token = StorageUtil.getToken();
  }

  /// GET 请求
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// POST 请求
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// PUT 请求
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.put(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// DELETE 请求
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.delete(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// 处理错误响应
  static String getErrorMessage(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return '连接超时，请检查网络';
        case DioExceptionType.sendTimeout:
          return '发送超时，请检查网络';
        case DioExceptionType.receiveTimeout:
          return '接收超时，请检查网络';
        case DioExceptionType.badResponse:
          final data = error.response?.data;
          if (data is Map && data['error'] != null) {
            return data['error'].toString();
          }
          return '服务器错误 (${error.response?.statusCode})';
        case DioExceptionType.cancel:
          return '请求已取消';
        case DioExceptionType.connectionError:
          return '网络连接失败，请检查网络';
        default:
          return '网络异常，请稍后重试';
      }
    }
    return error.toString();
  }
}
