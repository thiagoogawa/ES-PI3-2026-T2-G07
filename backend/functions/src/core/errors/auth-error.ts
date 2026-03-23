import {AppError} from "./app-error";

/**
 * Authentication-related application error.
 */
export class AuthError extends AppError {
  /**
   * Creates an authentication error payload.
   */
  constructor(
    message = "Authentication required",
    code = "UNAUTHENTICATED",
    details?: unknown,
  ) {
    super(message, 401, code, details);
    this.name = "AuthError";
  }
}
