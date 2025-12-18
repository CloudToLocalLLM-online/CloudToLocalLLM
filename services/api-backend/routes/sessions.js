import express from 'express';
const router = express.Router();
import db from '../database/db-pool.js';

/**
 * POST /auth/sessions
 * Legacy endpoint - now deprecated.
 * Sessions are now automatically synchronized via authenticateJWT middleware.
 */
router.post('/', async (req, res) => {
  res.status(410).json({
    error: 'Gone',
    message: 'This manual session registration endpoint is deprecated. Sessions are now handled automatically via JWT middleware.'
  });
});

/**
 * GET /auth/sessions/validate/:token
 * Validate a session token and return session data
 */
router.get('/validate/:token', async(req, res) => {
  try {
    const { token } = req.params;

    const result = await db.query(
      `SELECT s.id, s.session_token, s.expires_at,
              s.created_at, s.last_activity, s.is_active,
              u.id as user_id, u.jwt_id, u.email, u.name, u.nickname, u.picture
       FROM user_sessions s
       JOIN users u ON s.user_id = u.id
       WHERE s.session_token = $1 AND s.is_active = true AND s.expires_at > NOW()`,
      [token],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Session not found or expired' });
    }

    const session = result.rows[0];

    // Update last activity
    await db.query(
      'UPDATE user_sessions SET last_activity = NOW() WHERE id = $1',
      [session.id],
    );

    res.json({
      session: {
        id: session.id,
        token: session.session_token,
        expiresAt: session.expires_at,
        jwtAccessToken: session.jwt_access_token,
        jwtIdToken: session.jwt_id_token,
        createdAt: session.created_at,
        lastActivity: session.last_activity,
        isActive: session.is_active,
      },
      user: {
        id: session.jwt_id,
        email: session.email,
        name: session.name,
        nickname: session.nickname,
        picture: session.picture,
      },
    });
  } catch (error) {
    console.error('Error validating session:', error);
    res.status(500).json({ error: 'Failed to validate session' });
  }
});

/**
 * DELETE /auth/sessions/:token
 * Invalidate a session
 */
router.delete('/:token', async(req, res) => {
  try {
    const { token } = req.params;

    const result = await db.query(
      'UPDATE user_sessions SET is_active = false WHERE session_token = $1',
      [token],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Session not found' });
    }

    res.status(204).send();
  } catch (error) {
    console.error('Error invalidating session:', error);
    res.status(500).json({ error: 'Failed to invalidate session' });
  }
});

/**
 * POST /auth/sessions/cleanup
 * Clean up expired sessions
 */
router.post('/cleanup', async(req, res) => {
  try {
    const result = await db.query(
      'DELETE FROM user_sessions WHERE expires_at < NOW() OR is_active = false',
    );

    res.json({ deleted: result.rowCount });
  } catch (error) {
    console.error('Error cleaning up sessions:', error);
    res.status(500).json({ error: 'Failed to cleanup sessions' });
  }
});

export default router;
