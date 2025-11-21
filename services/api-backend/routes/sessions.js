import express from 'express';
const router = express.Router();
import db from '../database/db-pool.js';

/**
 * POST /auth/sessions
 * Create a new session for an authenticated user
 */
router.post('/', async (req, res) => {
  try {
    const {
      userId,
      token,
      expiresAt,
      auth0AccessToken,
      auth0IdToken,
      userProfile,
    } = req.body;

    if (!userId || !token || !expiresAt) {
      return res
        .status(400)
        .json({ error: 'Missing required fields: userId, token, expiresAt' });
    }

    // First, ensure user exists in users table with Auth0 profile data
    const result = await db.query(
      `INSERT INTO users (auth0_id, email, name, nickname, picture, email_verified, locale, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW())
       ON CONFLICT (auth0_id) DO UPDATE SET
         email = EXCLUDED.email,
         name = EXCLUDED.name,
         nickname = EXCLUDED.nickname,
         picture = EXCLUDED.picture,
         email_verified = EXCLUDED.email_verified,
         locale = EXCLUDED.locale,
         updated_at = NOW()
       RETURNING id`,
      [
        userId,
        userProfile?.email || `${userId}@auth0.local`,
        userProfile?.name || 'Unknown User',
        userProfile?.nickname || null,
        userProfile?.picture || null,
        userProfile?.email_verified || false,
        userProfile?.locale || null,
      ],
    );

    const dbUserId = result.rows[0].id;

    // Create session
    const sessionResult = await db.query(
      `INSERT INTO user_sessions (user_id, session_token, expires_at, auth0_access_token, auth0_id_token, created_at, last_activity)
       VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
       RETURNING id`,
      [dbUserId, token, expiresAt, auth0AccessToken, auth0IdToken],
    );

    res.status(201).json({
      id: sessionResult.rows[0].id,
      token: token,
      userId: dbUserId,
      expiresAt: expiresAt,
    });
  } catch (error) {
    console.error('Error creating session:', error);
    res.status(500).json({ error: 'Failed to create session' });
  }
});

/**
 * GET /auth/sessions/validate/:token
 * Validate a session token and return session data
 */
router.get('/validate/:token', async (req, res) => {
  try {
    const { token } = req.params;

    const result = await db.query(
      `SELECT s.id, s.session_token, s.expires_at, s.auth0_access_token, s.auth0_id_token,
              s.created_at, s.last_activity, s.is_active,
              u.id as user_id, u.auth0_id, u.email, u.name, u.nickname, u.picture
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
        auth0AccessToken: session.auth0_access_token,
        auth0IdToken: session.auth0_id_token,
        createdAt: session.created_at,
        lastActivity: session.last_activity,
        isActive: session.is_active,
      },
      user: {
        id: session.auth0_id,
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
router.delete('/:token', async (req, res) => {
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
router.post('/cleanup', async (req, res) => {
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
