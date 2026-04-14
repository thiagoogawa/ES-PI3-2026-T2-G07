import {Request, Response} from "express";
import {HTTP_STATUS} from "../../core/http/http-status";
import {successResponse} from "../../core/http/success-response";
import {StartupsService} from "./startups.service";

export class StartupsController {
  static async list(request: Request, response: Response): Promise<void> {
    const startups = await StartupsService.list({
      search: request.query.search?.toString(),
      stage: request.query.stage?.toString(),
    });

    response
      .status(HTTP_STATUS.OK)
      .json(successResponse(startups, "Startups fetched successfully"));
  }

  static async getById(request: Request, response: Response): Promise<void> {
    const startup = await StartupsService.getById(request.params.startupId);

    response
      .status(HTTP_STATUS.OK)
      .json(successResponse(startup, "Startup fetched successfully"));
  }
}
