import {
  DecodedIdToken,
  MultiFactorInfo,
  UserRecord,
} from "firebase-admin/auth";
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

interface MfaFactorPayload {
  uid: string;
  displayName: string | null;
  factorId: string | null;
  enrollmentTime: string | null;
  phoneNumber: string | null;
}

interface MfaStatusPayload {
  enabled: boolean;
  factors: MfaFactorPayload[];
}

/**
 * Service with Firebase Auth token operations.
 */
export class AuthService {
  private static buildMfaStatus(authUser: UserRecord): MfaStatusPayload {
    const factors = (authUser.multiFactor?.enrolledFactors ?? []).map(
      (factor: MultiFactorInfo) => ({
        uid: factor.uid,
        displayName: factor.displayName ?? null,
        factorId: factor.factorId,
        enrollmentTime: factor.enrollmentTime ?? null,
        phoneNumber: (factor as {phoneNumber?: string}).phoneNumber ?? null,
      }),
    );

    return {
      enabled: factors.length > 0,
      factors,
    };
  }

  private static async getAuthUser(uid: string): Promise<UserRecord> {
    return adminAuth.getUser(uid);
  }

  private static async syncMfaProfile(
    decodedToken: DecodedIdToken,
    authUser: UserRecord,
  ): Promise<MfaStatusPayload> {
    const mfa = this.buildMfaStatus(authUser);

    await syncBasicUserProfile(decodedToken, {
      phone: authUser.phoneNumber ?? decodedToken.phone_number ?? null,
      mfaEnabled: mfa.enabled,
    });

    return mfa;
  }

  private static async buildAuthenticatedUser(
    decodedToken: DecodedIdToken,
  ) {
    const authUser = await this.getAuthUser(decodedToken.uid);
    const mfa = await this.syncMfaProfile(decodedToken, authUser);
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
      mfa,
      account: {
        balance: account.balance,
        reservedBalance: account.reservedBalance,
        mfaEnabled: mfa.enabled,
        portfolioSize: Object.keys(account.portfolio).length,
      },
    };
  }

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
    return this.buildAuthenticatedUser(decodedToken);
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

    const authUser = await this.getAuthUser(decodedToken.uid);
    const mfa = await this.syncMfaProfile(decodedToken, authUser);

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
      mfa,
      account: {
        balance: account.balance,
        reservedBalance: account.reservedBalance,
        mfaEnabled: mfa.enabled,
        portfolioSize: Object.keys(account.portfolio).length,
      },
    };
  }

  static async getMfaStatus(decodedToken: DecodedIdToken) {
    const authUser = await this.getAuthUser(decodedToken.uid);
    return this.syncMfaProfile(decodedToken, authUser);
  }

  static async syncMfaState(decodedToken: DecodedIdToken) {
    const authUser = await this.getAuthUser(decodedToken.uid);
    return this.syncMfaProfile(decodedToken, authUser);
  }

  static async disableMfa(decodedToken: DecodedIdToken) {
    await adminAuth.updateUser(decodedToken.uid, {
      multiFactor: {
        enrolledFactors: null,
      },
    });

    const authUser = await this.getAuthUser(decodedToken.uid);
    return this.syncMfaProfile(decodedToken, authUser);
  }
}
