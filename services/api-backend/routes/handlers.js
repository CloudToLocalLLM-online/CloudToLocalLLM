import { logger } from '../utils/logger.js';
import { getHealthStatus } from '../services/health-check.js';
import { dbHealthHandler } from './db-health.js';
import { handleOllamaProxyRequest } from './ollama-proxy.js';
import { userTierHandler } from './user-tier.js';
import { versionInfoHandler } from './version-info.js';
import { queueStatusHandler, queueDrainHandler } from './queue.js';
import { proxyStartHandler, proxyStopHandler, proxyProvisionHandler, proxyStatusHandler } from './proxy.js';

export {
  logger,
  getHealthStatus,
  dbHealthHandler,
  handleOllamaProxyRequest,
  userTierHandler,
  versionInfoHandler,
  queueStatusHandler,
  queueDrainHandler,
  proxyStartHandler,
  proxyStopHandler,
  proxyProvisionHandler,
  proxyStatusHandler,
};
