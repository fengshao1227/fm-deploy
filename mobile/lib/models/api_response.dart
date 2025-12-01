/// API 统一响应模型
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? error;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.error,
  });

  /// 便捷成功构造器
  factory ApiResponse.success(T? data, {String? message}) {
    return ApiResponse(
      success: true,
      data: data,
      message: message,
    );
  }

  /// 便捷失败构造器
  factory ApiResponse.error(String error) {
    return ApiResponse(
      success: false,
      error: error,
    );
  }

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse(
      success: json['success'] ?? false,
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'],
      message: json['message'],
      error: json['error'],
    );
  }
}

/// 分页数据模型
class PaginatedData<T> {
  final List<T> list;
  final Pagination pagination;

  PaginatedData({
    required this.list,
    required this.pagination,
  });

  factory PaginatedData.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PaginatedData(
      list: (json['list'] as List? ?? [])
          .map((e) => fromJsonT(e as Map<String, dynamic>))
          .toList(),
      pagination: Pagination.fromJson(json['pagination'] ?? {}),
    );
  }
}

/// 分页信息
class Pagination {
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  Pagination({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: json['page'] ?? 1,
      pageSize: json['pageSize'] ?? 10,
      total: json['total'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
    );
  }

  bool get hasMore => page < totalPages;
}
