import {DecodedIdToken} from "firebase-admin/auth";
import {adminAuth} from "../../config/firebase-admin";
import {extractBearerToken} from "../../utils/extract-bearer-token";
import {AuthError} from "../../core/errors/auth-error";

/**
 * Service with Firebase Auth token operations.
 */
export class AuthService {
  /**
   * Verifies a Firebase ID token from the Authorization header.
   */
  static async verifyIdToken(
    authorizationHeader?: string,
  ): Promise<DecodedIdToken> {
    try {
      const token = extractBearerToken(authorizationHeader);
      return await adminAuth.verifyIdToken(token);
    } catch (error) {
      if (error instanceof AuthError) {
        throw error;
      }

      throw new AuthError(
        "Invalid or expired Firebase ID token",
        "INVALID_ID_TOKEN",
      );
    }
  }

  /**
   * Builds the public response payload for the authenticated user.
   */
  static buildWhoAmI(decodedToken: DecodedIdToken) {
    return {
      uid: decodedToken.uid,
      email: decodedToken.email ?? null,
      emailVerified: decodedToken.email_verified ?? false,
      name: decodedToken.name ?? null,
      picture: decodedToken.picture ?? null,
      provider: decodedToken.firebase?.sign_in_provider ?? null,
    };
  }
}
