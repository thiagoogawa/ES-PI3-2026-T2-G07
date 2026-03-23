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

    const user = AuthService.buildWhoAmI(request.user);

    response
      .status(HTTP_STATUS.OK)
      .json(successResponse(user, "Authenticated user fetched successfully"));
  }
}
