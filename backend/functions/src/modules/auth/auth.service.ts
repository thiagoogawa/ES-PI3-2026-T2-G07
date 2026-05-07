import {DecodedIdToken} from "firebase-admin/auth";
import {ValidationError} from "../../core/errors/validation-error";
import {adminAuth} from "../../config/firebase-admin";
import {extractBearerToken} from "../../utils/extract-bearer-token";
import {AuthError} from "../../core/errors/auth-error";
import {
  getOrCreateUserAccount,
  syncBasicUserProfile,
  updateUserProfile,
} from "../users/user-account.service";
import {StartupsService} from "../startups/startups.service";

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
  static async buildWhoAmI(decodedToken: DecodedIdToken) {
    await syncBasicUserProfile(decodedToken);
    const account = await getOrCreateUserAccount(decodedToken);
    const managedStartups = await StartupsService.listManagedByUser(
      decodedToken.uid,
    );
    const roles = new Set(account.roles);

    if (managedStartups.length > 0) {
      roles.add("startupAdmin");
    }

    return {
      uid: decodedToken.uid,
      email: decodedToken.email ?? null,
      emailVerified: decodedToken.email_verified ?? false,
      name: decodedToken.name ?? null,
      cpf: account.cpf,
      phone: account.phone,
      picture: account.picture ?? decodedToken.picture ?? null,
      provider: decodedToken.firebase?.sign_in_provider ?? null,
      roles: Array.from(roles),
      managedStartups,
      account: {
        balance: account.balance,
        reservedBalance: account.reservedBalance,
        mfaEnabled: account.mfaEnabled,
        portfolioSize: Object.keys(account.portfolio).length,
      },
    };
  }

  static async updateProfile(
    decodedToken: DecodedIdToken,
    input: Record<string, unknown>,
  ) {
    const name = input.name?.toString().trim() ?? "";
    const cpf = input.cpf?.toString().replace(/\D/g, "") ?? "";
    const phone = input.phone?.toString().trim() ?? "";
    const picture = input.picture?.toString().trim() ?? "";

    if (!name) {
      throw new ValidationError("name is required");
    }

    if (cpf.length != 11) {
      throw new ValidationError("cpf must contain 11 digits");
    }

    if (phone.length < 10) {
      throw new ValidationError("phone is invalid");
    }

    await adminAuth.updateUser(decodedToken.uid, {displayName: name});
    await updateUserProfile(decodedToken.uid, {
      name,
      cpf,
      phone,
      picture: picture || null,
    });

    const account = await getOrCreateUserAccount({
      ...decodedToken,
      name,
    });
    const managedStartups = await StartupsService.listManagedByUser(
      decodedToken.uid,
    );
    const roles = new Set(account.roles);

    if (managedStartups.length > 0) {
      roles.add("startupAdmin");
    }

    return {
      uid: decodedToken.uid,
      email: decodedToken.email ?? null,
      emailVerified: decodedToken.email_verified ?? false,
      name,
      cpf: account.cpf,
      phone: account.phone,
      picture: account.picture ?? decodedToken.picture ?? null,
      provider: decodedToken.firebase?.sign_in_provider ?? null,
      roles: Array.from(roles),
      managedStartups,
      account: {
        balance: account.balance,
        reservedBalance: account.reservedBalance,
        mfaEnabled: account.mfaEnabled,
        portfolioSize: Object.keys(account.portfolio).length,
      },
    };
  }
}
