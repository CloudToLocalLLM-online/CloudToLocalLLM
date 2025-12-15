import { logger } from '../utils/logger.js';
import { dbHealthHandler, setDbMigrator } from './db-health.js';
import { handleOllamaProxyRequest, setSshProxy } from './ollama-proxy.js';
import { userTierHandler } from './user-tier.js';
import { versionInfoHandler } from './version-info.js';
import { queueStatusHandler, queueDrainHandler } from './queue.js';
import {
  proxyStartHandler,
  proxyStopHandler,
  proxyProvisionHandler,
  proxyStatusHandler,
} from './proxy.js';

export {
  logger,
  dbHealthHandler,
  setDbMigrator,
  handleOllamaProxyRequest,
  setSshProxy,
  userTierHandler,
  versionInfoHandler,
  queueStatusHandler,
  queueDrainHandler,
  proxyStartHandler,
  proxyStopHandler,
  proxyProvisionHandler,
  proxyStatusHandler,
};
