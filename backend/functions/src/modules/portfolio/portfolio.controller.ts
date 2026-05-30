/**
 * Thiago Ryuji Ogawa - RA:24024450
 * Lucca Schroelder Scovini - RA: 24011609
 *
 * Controller HTTP do modulo de portfolio.
 * Traduz requisicoes e respostas Express para chamadas de alto
 * nivel nas regras de negocio do respectivo modulo.
 */

import {Request, Response} from "express";
import {AuthError} from "../../core/errors/auth-error";
import {HTTP_STATUS} from "../../core/http/http-status";
import {successResponse} from "../../core/http/success-response";
import {PortfolioService} from "./portfolio.service";

export class PortfolioController {
  static async getPortfolio(
    request: Request,
    response: Response,
  ): Promise<void> {
    if (!request.user) {
      throw new AuthError();
    }

    const portfolio = await PortfolioService.getPortfolio(request.user);

    response
      .status(HTTP_STATUS.OK)
      .json(successResponse(portfolio, "Portfolio fetched successfully"));
  }

  static async getDashboard(
    request: Request,
    response: Response,
  ): Promise<void> {
    if (!request.user) {
      throw new AuthError();
    }

    const dashboard = await PortfolioService.getDashboard(
      request.user,
      request.query.period?.toString(),
    );

    response
      .status(HTTP_STATUS.OK)
      .json(successResponse(dashboard, "Dashboard fetched successfully"));
  }

  static async depositBalance(
    request: Request,
    response: Response,
  ): Promise<void> {
    if (!request.user) {
      throw new AuthError();
    }

    const portfolio = await PortfolioService.depositBalance(
      request.user,
      (request.body ?? {}) as Record<string, unknown>,
    );

    response
      .status(HTTP_STATUS.OK)
      .json(successResponse(portfolio, "Balance credited successfully"));
  }
}
