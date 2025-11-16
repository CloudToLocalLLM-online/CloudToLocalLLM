import { Request, Response, NextFunction } from 'express';
import { AuthMiddleware } from '../interfaces/auth-middleware.js';
import { ConsoleLogger } from '../utils/logger.js';

const logger = new ConsoleLogger('AdminAuthMiddleware');

/**
 * Admin authentication middleware
 * Checks if the user has admin privileges
 * Requires JWT validation middleware to run first
 */
export function createAdminAuthMiddleware(authMiddleware: AuthMiddleware) {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      // Get token from Authorization header
      const authHeader = req.headers.authorization;
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        logger.warn('Missing or invalid Authorization header', {
          path: req.path,
          method: req.method,
        });
        res.status(401).json({ error: 'Missing or invalid Authorization header' });
        return;
      }

      const token = authHeader.substring(7);

      // Validate token
      const validation = await authMiddleware.validateToken(token);
      if (!validation.valid) {
        logger.warn('Token validation failed', {
          path: req.path,
          method: req.method,
          error: validation.error,
        });
        res.status(401).json({ error: 'Invalid or expired token' });
        return;
      }

      // Get user context
      const userContext = await authMiddleware.getUserContext(token);

      // Check if user is admin (for now, check if tier is ENTERPRISE)
      // In a real application, you would check a specific admin flag or role
      const isAdmin = userContext.tier === 'enterprise' || (userContext as any).isAdmin === true;

      if (!isAdmin) {
        logger.warn('Unauthorized admin access attempt', {
          userId: userContext.userId,
          path: req.path,
          method: req.method,
        });
        res.status(403).json({ error: 'Admin access required' });
        return;
      }

      // Attach user context to request
      (req as any).user = userContext;
      (req as any).userId = userContext.userId;

      next();
    } catch (error) {
      logger.error('Error in admin auth middleware', {
        error: error instanceof Error ? error : new Error(String(error)),
        path: req.path,
        method: req.method,
      });
      res.status(500).json({ error: 'Internal server error' });
    }
  };
}
