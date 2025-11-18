import express from 'express';
import path from 'path';
import { promises as fs } from 'fs';

const router = express.Router();
const logDir = process.env.CLIENT_LOG_DIR || '/var/log/cloudtolocalllm';
const logFileName = process.env.CLIENT_LOG_FILE || 'client-web.log';
const logFilePath = path.join(logDir, logFileName);

async function ensureLogDirectory() {
  await fs.mkdir(logDir, { recursive: true });
}

router.post('/', async(req, res) => {
  try {
    const { entries, source = 'web-client', sessionId = null } = req.body || {};

    if (!Array.isArray(entries) || entries.length === 0) {
      return res.status(400).json({ error: 'entries array is required' });
    }

    const sanitized = entries.slice(0, 200).map((entry) => ({
      timestamp: entry?.timestamp || new Date().toISOString(),
      level: entry?.level || 'INFO',
      message:
        typeof entry?.message === 'string'
          ? entry.message
          : JSON.stringify(entry?.message ?? ''),
      url: entry?.url || null,
      userAgent: entry?.userAgent || req.get('user-agent') || null,
      source,
      sessionId,
    }));

    await ensureLogDirectory();
    const payload =
      sanitized.map((entry) => JSON.stringify(entry)).join('\n') + '\n';
    await fs.appendFile(logFilePath, payload, 'utf8');

    res.json({ success: true, count: sanitized.length });
  } catch (error) {
    console.error('[ClientLogs] Failed to persist log entries', error);
    res.status(500).json({ error: 'Failed to persist logs' });
  }
});

export default router;
