import { Router } from 'express';
import { AuthController } from '../controllers/AuthController';
import { ProjectController } from '../controllers/ProjectController';
import { EnvironmentController } from '../controllers/EnvironmentController';
import { ProjectEnvironmentController } from '../controllers/ProjectEnvironmentController';
import { DeploymentController } from '../controllers/DeploymentController';
import { authMiddleware, requireRole } from '../middlewares/auth';

const router = Router();

// ============ 认证路由 ============
router.post('/auth/login', AuthController.login);
router.get('/auth/me', authMiddleware, AuthController.me);
router.post('/auth/change-password', authMiddleware, AuthController.changePassword);

// ============ 项目管理路由 ============
router.get('/projects/all', authMiddleware, ProjectController.getAll);
router.get('/projects', authMiddleware, ProjectController.list);
router.get('/projects/:id', authMiddleware, ProjectController.getById);
router.post('/projects', authMiddleware, requireRole('admin'), ProjectController.create);
router.put('/projects/:id', authMiddleware, requireRole('admin'), ProjectController.update);
router.delete('/projects/:id', authMiddleware, requireRole('admin'), ProjectController.delete);

// ============ 环境管理路由 ============
router.get('/environments/all', authMiddleware, EnvironmentController.getAll);
router.get('/environments', authMiddleware, EnvironmentController.list);
router.get('/environments/:id', authMiddleware, EnvironmentController.getById);
router.post('/environments', authMiddleware, requireRole('admin'), EnvironmentController.create);
router.put('/environments/:id', authMiddleware, requireRole('admin'), EnvironmentController.update);
router.delete('/environments/:id', authMiddleware, requireRole('admin'), EnvironmentController.delete);
router.post('/environments/:id/test', authMiddleware, EnvironmentController.testConnection);

// ============ 项目环境配置路由 ============
router.get('/projects/:projectId/environments', authMiddleware, ProjectEnvironmentController.listByProject);
router.post('/projects/:projectId/environments', authMiddleware, requireRole('admin'), ProjectEnvironmentController.create);
router.get('/project-environments/:id', authMiddleware, ProjectEnvironmentController.getById);
router.put('/project-environments/:id', authMiddleware, requireRole('admin'), ProjectEnvironmentController.update);
router.delete('/project-environments/:id', authMiddleware, requireRole('admin'), ProjectEnvironmentController.delete);
router.post('/project-environments/:id/toggle', authMiddleware, requireRole('admin'), ProjectEnvironmentController.toggle);

// ============ 部署管理路由 ============
router.get('/deployments', authMiddleware, DeploymentController.list);
router.get('/deployments/:id', authMiddleware, DeploymentController.getById);
router.post('/deployments', authMiddleware, DeploymentController.create);
router.get('/deployments/:id/logs', authMiddleware, DeploymentController.getLogs);
router.post('/deployments/:id/rollback', authMiddleware, DeploymentController.rollback);
router.post('/deployments/:id/cancel', authMiddleware, DeploymentController.cancel);
router.get('/projects/:projectId/deployments', authMiddleware, DeploymentController.listByProject);

// ============ 版本回滚路由 ============
router.get('/project-environments/:id/versions', authMiddleware, DeploymentController.getVersions);
router.post('/snapshots/:snapshotId/rollback', authMiddleware, DeploymentController.rollbackToVersion);

// ============ 健康检查 ============
router.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
  });
});

export default router;
