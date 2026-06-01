/**
 * Thiago Ryuji Ogawa - RA:24024450
 * Centraliza a logica de autenticacao e perfil do usuario.
 *
 * Centraliza validacao do token Firebase, sincronizacao basica do perfil do
 * usuario e montagem do payload devolvido para o mobile em /v1/auth.
 */

import {DecodedIdToken} from "firebase-admin/auth";
import {ValidationError} from "../../core/errors/validation-error";
import {adminAuth} from "../../config/firebase-admin";
import {extractBearerToken} from "../../utils/extract-bearer-token";
import {AuthError} from "../../core/errors/auth-error";
import {
  getOrCreateUserAccount,
  syncBasicUserProfile,
  syncUserMfaState,
  updateUserProfile,
} from "../users/user-account.service";
import {StartupsService} from "../startups/startups.service";

/**
 * Encapsula operacoes de autenticacao e montagem do perfil autenticado.
 */
export class AuthService {
  /**
   * Valida o bearer token recebido no header Authorization.
   *
   * Se o token for invalido, ausente ou expirado, a excecao eh convertida para
   * [AuthError] com um codigo semantico consumivel pela API.
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
    * Monta o payload publico devolvido ao mobile em /auth/me.
    *
    * Alem dos dados do token, agrega perfil persistido, saldo, papeis e a lista
    * de startups que o usuario administra.
   */
  static async buildWhoAmI(decodedToken: DecodedIdToken) {
    await syncBasicUserProfile(decodedToken);
    const account = await getOrCreateUserAccount(decodedToken);
    const mfaEnabled = await syncUserMfaState(decodedToken.uid);
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
      name: account.name ?? decodedToken.name ?? null,
      cpf: account.cpf,
      phone: account.phone,
      picture: account.picture ?? decodedToken.picture ?? null,
      provider: decodedToken.firebase?.sign_in_provider ?? null,
      roles: Array.from(roles),
      managedStartups,
      account: {
        balance: account.balance,
        reservedBalance: account.reservedBalance,
        mfaEnabled,
        portfolioSize: Object.keys(account.portfolio).length,
      },
    };
  }

  /**
   * Atualiza o perfil persistido do usuario autenticado.
   *
   * O metodo aplica validacoes basicas de nome, CPF e telefone, tenta refletir
   * o nome tambem no Firebase Auth e devolve o mesmo formato resumido usado em
   * [buildWhoAmI].
   */
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

    try {
      await adminAuth.updateUser(decodedToken.uid, {displayName: name});
    } catch (_error) {
      // Keep profile edits working even if the function service account
      // cannot update Firebase Auth user attributes in this environment.
    }

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
    const mfaEnabled = await syncUserMfaState(decodedToken.uid);
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
        mfaEnabled,
        portfolioSize: Object.keys(account.portfolio).length,
      },
    };
  }
}
