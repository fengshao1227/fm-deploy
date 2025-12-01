import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../pages/login/login_page.dart';
import '../pages/home/home_page.dart';
import '../pages/projects/projects_page.dart';
import '../pages/projects/project_detail_page.dart';
import '../pages/environments/environments_page.dart';
import '../pages/environments/environment_detail_page.dart';
import '../pages/deployments/deployments_page.dart';
import '../pages/deployments/deployment_detail_page.dart';
import '../pages/deployments/deploy_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/settings/change_password_page.dart';
import '../pages/versions/versions_list_page.dart'; // New import
import '../pages/project_environments/edit_project_environment_page.dart'; // New import
import '../pages/projects/add_project_page.dart'; // New import
import '../pages/environments/add_environment_page.dart'; // New import
import '../pages/project_environments/add_project_environment_page.dart'; // New import
import '../widgets/common/main_scaffold.dart';
import '../utils/storage_util.dart';

/// 路由路径常量
class AppRoutes {
  static const String login = '/login';
  static const String home = '/';
  static const String projects = '/projects';
  static const String projectDetail = '/projects/:id';
  static const String environments = '/environments';
  static const String environmentDetail = '/environments/:id';
  static const String deployments = '/deployments';
  static const String deploymentDetail = '/deployments/:id';
  static const String deploy = '/deploy';
  static const String settings = '/settings';
  static const String changePassword = '/settings/change-password';
  static const String projectEnvironmentVersions = '/project-environments/:projectEnvironmentId/versions';
  static const String editProjectEnvironment = '/project-environments/:id/edit';
  static const String addProject = '/projects/add';
  static const String addEnvironment = '/environments/add';
  static const String addProjectEnvironment = '/projects/:projectId/environments/add';
}

/// 路由配置
final appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  redirect: (context, state) {
    final isLoggedIn = StorageUtil.isLoggedIn();
    final isLoginRoute = state.matchedLocation == AppRoutes.login;

    // 未登录且不是登录页，跳转到登录页
    if (!isLoggedIn && !isLoginRoute) {
      return AppRoutes.login;
    }

    // 已登录且在登录页，跳转到首页
    if (isLoggedIn && isLoginRoute) {
      return AppRoutes.home;
    }

    return null;
  },
  routes: [
    // 登录页（不带底部导航）
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginPage(),
    ),

    // 主页面（带底部导航）
    ShellRoute(
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.home,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomePage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.projects,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ProjectsPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.deployments,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: DeploymentsPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.settings,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsPage(),
          ),
        ),
      ],
    ),

    // 添加项目页
    GoRoute(
      path: AppRoutes.addProject,
      builder: (context, state) => const AddProjectPage(),
    ),

    // 项目详情页（不带底部导航）
    GoRoute(
      path: AppRoutes.projectDetail,
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        return ProjectDetailPage(projectId: id);
      },
    ),

    // 环境列表页
    GoRoute(
      path: AppRoutes.environments,
      builder: (context, state) => const EnvironmentsPage(),
    ),

    // 添加环境页
    GoRoute(
      path: AppRoutes.addEnvironment,
      builder: (context, state) => const AddEnvironmentPage(),
    ),

    // 环境详情页
    GoRoute(
      path: AppRoutes.environmentDetail,
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        return EnvironmentDetailPage(environmentId: id);
      },
    ),

    // 部署详情页
    GoRoute(
      path: AppRoutes.deploymentDetail,
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        return DeploymentDetailPage(deploymentId: id);
      },
    ),

    // 执行部署页
    GoRoute(
      path: AppRoutes.deploy,
      builder: (context, state) {
        final projectId =
            int.tryParse(state.uri.queryParameters['projectId'] ?? '');
        return DeployPage(projectId: projectId);
      },
    ),

    // 项目环境历史版本页
    GoRoute(
      path: AppRoutes.projectEnvironmentVersions,
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['projectEnvironmentId'] ?? '') ?? 0;
        return VersionsListPage(projectEnvironmentId: id);
      },
    ),

    // 编辑项目环境配置页
    GoRoute(
      path: AppRoutes.editProjectEnvironment,
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        return EditProjectEnvironmentPage(projectEnvironmentId: id);
      },
    ),

    // 添加项目环境配置页
    GoRoute(
      path: AppRoutes.addProjectEnvironment,
      builder: (context, state) {
        final projectId =
            int.tryParse(state.pathParameters['projectId'] ?? '') ?? 0;
        return AddProjectEnvironmentPage(projectId: projectId);
      },
    ),

    // 修改密码页（不带底部导航）
    GoRoute(
      path: AppRoutes.changePassword,
      builder: (context, state) => const ChangePasswordPage(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('页面不存在: ${state.uri}'),
    ),
  ),
);
