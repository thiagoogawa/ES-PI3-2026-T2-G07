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

  static async getMfaStatus(
    request: Request,
    response: Response,
  ): Promise<void> {
    if (!request.user) {
      throw new AuthError();
    }

    const mfa = await AuthService.getMfaStatus(request.user);

    response
      .status(HTTP_STATUS.OK)
      .json(successResponse(mfa, "MFA status fetched successfully"));
  }

  static async syncMfaStatus(
    request: Request,
    response: Response,
  ): Promise<void> {
    if (!request.user) {
      throw new AuthError();
    }

    const mfa = await AuthService.syncMfaState(request.user);

    response
      .status(HTTP_STATUS.OK)
      .json(successResponse(mfa, "MFA status synced successfully"));
  }

  static async disableMfa(
    request: Request,
    response: Response,
  ): Promise<void> {
    if (!request.user) {
      throw new AuthError();
    }

    const mfa = await AuthService.disableMfa(request.user);

    response
      .status(HTTP_STATUS.OK)
      .json(successResponse(mfa, "MFA disabled successfully"));
  }
}
