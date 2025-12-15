import express from 'express';
const router = express.Router();
import db from '../database/db-pool.js';

/**
 * POST /auth/sessions
 * Create a new session for an authenticated user
 */
router.post('/', async(req, res) => {
  try {
    const { userId, token, expiresAt, userProfile } = req.body;

    if (!userId || !token || !expiresAt) {
      return res
        .status(400)
        .json({ error: 'Missing required fields: userId, token, expiresAt' });
    }

    // First, ensure user exists in users table with JWT profile data
    // Robust User Resolution Logic
    // 1. Try to find user by jwt_id
    let dbUserId;
    const existingByJwt = await db.query(
      'SELECT id FROM users WHERE jwt_id = $1',
      [userId],
    );

    if (existingByJwt.rows.length > 0) {
      dbUserId = existingByJwt.rows[0].id;
      // Update user profile
      await db.query(
        `UPDATE users SET
           email = $1, name = $2, nickname = $3, picture = $4,
           email_verified = $5, locale = $6, updated_at = NOW()
         WHERE id = $7`,
        [
          userProfile?.email || `${userId}@jwt.local`,
          userProfile?.name || 'Unknown User',
          userProfile?.nickname || null,
          userProfile?.picture || null,
          userProfile?.email_verified || false,
          userProfile?.locale || null,
          dbUserId,
        ],
      );
    } else {
      // 2. Try to find user by email (fallback for migration)
      const email = userProfile?.email || `${userId}@jwt.local`;
      const existingByEmail = await db.query(
        'SELECT id FROM users WHERE email = $1',
        [email],
      );

      if (existingByEmail.rows.length > 0) {
        dbUserId = existingByEmail.rows[0].id;
        // User exists but has no jwt_id (or different one?). Link current jwt_id.
        await db.query(
          `UPDATE users SET
             jwt_id = $1, name = $2, nickname = $3, picture = $4,
             email_verified = $5, locale = $6, updated_at = NOW()
           WHERE id = $7`,
          [
            userId,
            userProfile?.name || 'Unknown User',
            userProfile?.nickname || null,
            userProfile?.picture || null,
            userProfile?.email_verified || false,
            userProfile?.locale || null,
            dbUserId,
          ],
        );
      } else {
        // 3. Create new user
        const result = await db.query(
          `INSERT INTO users (jwt_id, email, name, nickname, picture, email_verified, locale, created_at, updated_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW())
           RETURNING id`,
          [
            userId,
            email,
            userProfile?.name || 'Unknown User',
            userProfile?.nickname || null,
            userProfile?.picture || null,
            userProfile?.email_verified || false,
            userProfile?.locale || null,
          ],
        );
        dbUserId = result.rows[0].id;
      }
    }

    // dbUserId is already assigned in logic above

    // Create session
    const sessionResult = await db.query(
      `INSERT INTO user_sessions (user_id, session_token, expires_at, created_at, last_activity)
       VALUES ($1, $2, $3, NOW(), NOW())
       ON CONFLICT (session_token)
       DO UPDATE SET
         last_activity = NOW(),
         expires_at = EXCLUDED.expires_at,
         user_id = EXCLUDED.user_id
       RETURNING id`,
      [dbUserId, token, expiresAt],
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
