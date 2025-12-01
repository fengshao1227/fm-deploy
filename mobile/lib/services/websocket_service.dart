import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import '../models/deployment.dart';
import '../utils/storage_util.dart';

/// WebSocket 服务
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  bool _isConnected = false;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _reconnectDelay = Duration(seconds: 3);

  // 事件流控制器
  final _connectionController = StreamController<bool>.broadcast();
  final _logController = StreamController<RealtimeLog>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // 公开的事件流
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<RealtimeLog> get logStream => _logController.stream;
  Stream<String> get errorStream => _errorController.stream;

  bool get isConnected => _isConnected;

  /// 触发当前连接状态（供新监听者获取当前状态）
  void emitCurrentStatus() {
    _connectionController.add(_isConnected);
  }

  // 已订阅的部署ID
  final Set<int> _subscribedDeployments = {};

  /// 连接 WebSocket
  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;

    final token = StorageUtil.getToken();
    if (token == null) {
      _errorController.add('未登录，无法连接');
      return;
    }

    _isConnecting = true;

    try {
      final wsUrl = '${ApiConfig.wsUrl}?token=$token';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _subscription = _channel?.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
      );

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      _connectionController.add(true);

      // 启动心跳
      _startHeartbeat();

      // 重新订阅之前的部署
      for (final deploymentId in _subscribedDeployments) {
        _sendSubscribe(deploymentId);
      }
    } catch (e) {
      _isConnecting = false;
      _errorController.add('连接失败: $e');
      _scheduleReconnect();
    }
  }

  /// 断开连接
  void disconnect() {
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
    _connectionController.add(false);
  }

  /// 订阅部署日志
  void subscribeDeployment(int deploymentId) {
    _subscribedDeployments.add(deploymentId);
    if (_isConnected) {
      _sendSubscribe(deploymentId);
    }
  }

  /// 取消订阅部署日志
  void unsubscribeDeployment(int deploymentId) {
    _subscribedDeployments.remove(deploymentId);
    if (_isConnected) {
      _sendUnsubscribe(deploymentId);
    }
  }

  /// 发送订阅消息
  void _sendSubscribe(int deploymentId) {
    _send({
      'type': 'subscribe_deployment',
      'payload': {'deploymentId': deploymentId},
    });
  }

  /// 发送取消订阅消息
  void _sendUnsubscribe(int deploymentId) {
    _send({
      'type': 'unsubscribe_deployment',
      'payload': {'deploymentId': deploymentId},
    });
  }

  /// 发送心跳
  void _sendPing() {
    _send({'type': 'ping', 'payload': {}});
  }

  /// 发送消息
  void _send(Map<String, dynamic> message) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  /// 处理收到的消息
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;
      final payload = data['payload'] as Map<String, dynamic>?;

      switch (type) {
        case 'connected':
          // 连接成功
          break;
        case 'subscribed':
          // 订阅成功
          break;
        case 'deployment_log':
          if (payload != null) {
            final log = RealtimeLog.fromJson(payload);
            _logController.add(log);
          }
          break;
        case 'pong':
          // 心跳响应
          break;
        case 'error':
          final errorMsg = payload?['message'] as String? ?? '未知错误';
          _errorController.add(errorMsg);
          break;
      }
    } catch (e) {
      _errorController.add('消息解析失败: $e');
    }
  }

  /// 处理错误
  void _handleError(dynamic error) {
    _errorController.add('WebSocket 错误: $error');
    _handleDone();
  }

  /// 处理连接关闭
  void _handleDone() {
    _isConnected = false;
    _connectionController.add(false);
    _stopHeartbeat();
    _scheduleReconnect();
  }

  /// 启动心跳
  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _sendPing();
    });
  }

  /// 停止心跳
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 安排重连
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _errorController.add('重连次数已达上限');
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      _reconnectAttempts++;
      connect();
    });
  }

  /// 销毁服务
  void dispose() {
    disconnect();
    _connectionController.close();
    _logController.close();
    _errorController.close();
  }
}
