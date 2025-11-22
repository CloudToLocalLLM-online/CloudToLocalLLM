import { describe, it, expect } from '@jest/globals';
import {
  TransactionManager,
} from '../services/transaction-manager.js';

describe('TransactionManager', () => {
  it('should be defined', () => {
    expect(TransactionManager).toBeDefined();
  });
});
