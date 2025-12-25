import { TokenValidationResult } from '../interfaces/auth-middleware';

export interface JWTValidator {
  validateToken(token: string): Promise<TokenValidationResult>;
}
