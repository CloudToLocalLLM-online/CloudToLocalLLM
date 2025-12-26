import { TokenValidationResult } from '../interfaces/auth-middleware';
import { JWTValidator } from './jwt-validator.interface';
import jwt from 'jsonwebtoken';
import jwksClient from 'jwks-rsa';

interface JWTPayload {
  sub: string;
  iss: string;
  aud: string | string[];
  exp: number;
  iat: number;
  [key: string]: any;
}

export class Auth0JWTValidator implements JWTValidator {
  private readonly client: jwksClient.JwksClient;
  private readonly audience: string;

  constructor(jwksUri: string, audience: string) {
    this.audience = audience;
    this.client = jwksClient({
      jwksUri,
      cache: true,
      rateLimit: true,
      jwksRequestsPerMinute: 5,
    });
  }

  private getKey(header: jwt.JwtHeader, callback: jwt.SigningKeyCallback) {
    this.client.getSigningKey(header.kid, (err: Error | null, key?: jwksClient.SigningKey) => {
      if (err) {
        callback(err);
        return;
      }
      const signingKey = key?.getPublicKey();
      callback(null, signingKey);
    });
  }

  async validateToken(token: string): Promise<TokenValidationResult> {
    return new Promise((resolve) => {
      jwt.verify(
        token,
        this.getKey.bind(this),
        { algorithms: ['RS256'] },
        (err: jwt.VerifyErrors | null, decoded: string | jwt.JwtPayload | undefined) => {
          if (err) {
            if (err instanceof jwt.TokenExpiredError) {
              const decodedToken = jwt.decode(token) as JWTPayload;
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

          const payload = decoded as JWTPayload;

          if (payload.aud !== this.audience) {
            resolve({
              valid: false,
              error: `Invalid audience: expected ${this.audience}, got ${payload.aud}`,
            });
            return;
          }

          resolve({
            valid: true,
            userId: payload.sub,
            expiresAt: new Date(payload.exp * 1000),
          });
        }
      );
    });
  }
}
