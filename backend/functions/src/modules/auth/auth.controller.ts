/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Controller HTTP do modulo de autenticacao.
 * Traduz requisicoes e respostas Express para chamadas de alto
 * nivel nas regras de negocio do respectivo modulo.
 */

import {Request, Response} from "express";
import {successResponse} from "../../core/http/success-response";
import {HTTP_STATUS} from "../../core/http/http-status";
import {AuthService} from "./auth.service";
import {AuthError} from "../../core/errors/auth-error";

/**
 * Controller for authenticated user endpoints.
 */
export class AuthController {
  /**
   * Returns the authenticated user payload.
   */
  static async whoAmI(request: Request, response: Response): Promise<void> {
    if (!request.user) {
      throw new AuthError();
    }

    const user = await AuthService.buildWhoAmI(request.user);

    response
      .status(HTTP_STATUS.OK)
      .json(successResponse(user, "Authenticated user fetched successfully"));
  }

  static async updateProfile(
    request: Request,
    response: Response,
  ): Promise<void> {
    if (!request.user) {
      throw new AuthError();
    }

    const user = await AuthService.updateProfile(
      request.user,
      request.body as Record<string, unknown>,
    );

    response
      .status(HTTP_STATUS.OK)
      .json(successResponse(user, "Authenticated user updated successfully"));
  }
}
