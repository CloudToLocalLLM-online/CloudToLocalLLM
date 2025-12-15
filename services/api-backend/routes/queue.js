import {
  createQueueStatusHandler,
  createQueueDrainHandler,
} from '../middleware/request-queuing.js';

export const queueStatusHandler = createQueueStatusHandler();
export const queueDrainHandler = createQueueDrainHandler();
