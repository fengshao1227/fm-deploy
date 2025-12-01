import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router/app_router.dart';
import 'utils/storage_util.dart';
import 'services/api_service.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化本地存储
  await StorageUtil.init();

  // 恢复 Token
  ApiService().restoreToken();

  runApp(
    const ProviderScope(
      child: FMDeployApp(),
    ),
  );
}

class FMDeployApp extends ConsumerStatefulWidget {
  const FMDeployApp({super.key});

  @override
  ConsumerState<FMDeployApp> createState() => _FMDeployAppState();
}

class _FMDeployAppState extends ConsumerState<FMDeployApp> {
  @override
  void initState() {
    super.initState();
    // 初始化认证状态
    Future.microtask(() {
      ref.read(authProvider.notifier).init();
    });

    // 设置 401 回调
    ApiService().onUnauthorized = () {
      ref.read(authProvider.notifier).logout();
      appRouter.go('/login');
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FM Deploy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.grey.shade200,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}
