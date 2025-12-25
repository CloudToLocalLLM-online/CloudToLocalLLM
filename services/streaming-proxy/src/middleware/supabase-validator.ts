import { TokenValidationResult } from '../interfaces/auth-middleware';
import { JWTValidator } from './jwt-validator.interface';
import jwt from 'jsonwebtoken';

export class SupabaseJWTValidator implements JWTValidator {
  private readonly jwtSecret: string;

  constructor(jwtSecret: string) {
    this.jwtSecret = jwtSecret;
  }

  async validateToken(token: string): Promise<TokenValidationResult> {
    return new Promise((resolve) => {
      jwt.verify(
        token,
        this.jwtSecret,
        { algorithms: ['HS256'] },
        (err: jwt.VerifyErrors | null, decoded: any) => {
          if (err) {
            if (err instanceof jwt.TokenExpiredError) {
              const decodedToken = jwt.decode(token) as any;
              resolve({
                valid: false,
                error: 'Token expired',
                userId: decodedToken?.sub,
                expiresAt: decodedToken?.exp ? new Date(decodedToken.exp * 1000) : undefined,
              });
            } else {
              resolve({
                valid: false,
                error: err.message,
              });
            }
            return;
          }

          resolve({
            valid: true,
            userId: decoded.sub,
            expiresAt: new Date(decoded.exp * 1000),
          });
        }
      );
    });
  }
}
