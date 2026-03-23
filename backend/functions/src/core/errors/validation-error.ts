import {AppError} from "./app-error";

/**
 * Validation-related application error.
 */
export class ValidationError extends AppError {
  /**
   * Creates a validation error payload.
   */
  constructor(
    message = "Validation failed",
    code = "VALIDATION_ERROR",
    details?: unknown,
  ) {
    super(message, 400, code, details);
    this.name = "ValidationError";
  }
}
