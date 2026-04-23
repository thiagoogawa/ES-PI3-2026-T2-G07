import {DecodedIdToken} from "firebase-admin/auth";
import {ValidationError} from "../../core/errors/validation-error";
import {adminDb} from "../../config/firebase-admin";
import {
  creditUserBalance,
  getOrCreateUserAccount,
} from "../users/user-account.service";
import {readNumber, readString, toIsoDate} from "../../utils/firestore-helpers";

type DashboardPeriod = "1d" | "7d" | "1m" | "6m" | "ytd";
const DEFAULT_SIMULATED_DEPOSIT_AMOUNT = 10000;

const resolvePeriodStart = (period: DashboardPeriod): Date => {
  const now = new Date();
  const startDate = new Date(now);

  switch (period) {
  case "1d":
    startDate.setDate(now.getDate() - 1);
    return startDate;
  case "7d":
    startDate.setDate(now.getDate() - 7);
    return startDate;
  case "1m":
    startDate.setMonth(now.getMonth() - 1);
    return startDate;
  case "6m":
    startDate.setMonth(now.getMonth() - 6);
    return startDate;
  case "ytd":
    return new Date(now.getFullYear(), 0, 1);
  }
};

const parsePeriod = (value?: string): DashboardPeriod => {
  if (
    value === "1d" ||
    value === "7d" ||
    value === "1m" ||
    value === "6m" ||
    value === "ytd"
  ) {
    return value;
  }

  return "1m";
};

export class PortfolioService {
  static async getPortfolio(decodedToken: DecodedIdToken) {
    const account = await getOrCreateUserAccount(decodedToken);
    const positions = await PortfolioService.buildPositions(account.portfolio);
    const totalInvested = positions.reduce(
      (sum, position) => sum + position.investedAmount,
      0,
    );
    const currentValue = positions.reduce(
      (sum, position) => sum + position.currentValue,
      0,
    );

    return {
      user: {
        uid: account.uid,
        name: account.name,
        email: account.email,
      },
      balance: account.balance,
      reservedBalance: account.reservedBalance,
      totalInvested,
      currentValue,
      profitLoss: currentValue - totalInvested,
      positions,
      updatedAt: account.updatedAt,
    };
  }

  static async getDashboard(
    decodedToken: DecodedIdToken,
    requestedPeriod?: string,
  ) {
    const period = parsePeriod(requestedPeriod);
    const portfolio = await PortfolioService.getPortfolio(decodedToken);
    const timeline = await PortfolioService.buildTimeline(
      portfolio.positions,
      resolvePeriodStart(period),
    );

    return {
      period,
      summary: {
        balance: portfolio.balance,
        reservedBalance: portfolio.reservedBalance,
        totalInvested: portfolio.totalInvested,
        currentValue: portfolio.currentValue,
        profitLoss: portfolio.profitLoss,
      },
      distribution: portfolio.positions.map((position) => ({
        startupId: position.startupId,
        startupName: position.startupName,
        allocationValue: position.currentValue,
        allocationPercent: portfolio.currentValue > 0 ?
          (position.currentValue / portfolio.currentValue) * 100 :
          0,
      })),
      positions: portfolio.positions,
      timeline,
    };
  }

  private static async buildPositions(
    portfolio: Record<string, {
      startupId: string;
      startupName: string;
      quantity: number;
      averagePrice: number;
      investedAmount: number;
    }>,
  ) {
    const startupIds = Object.keys(portfolio);
    const startupSnapshots = await Promise.all(
      startupIds.map((startupId) => {
        return adminDb.collection("startups").doc(startupId).get();
      }),
    );

    return startupSnapshots.map((snapshot) => {
      const startupId = snapshot.id;
      const position = portfolio[startupId];
      const source = snapshot.data() ?? {};
      const currentPrice = readNumber(
        source,
        [
          "valorTokenAtual",
          "precoAtual",
          "currentPrice",
          "tokenPrice",
          "valorToken",
        ],
        position.averagePrice,
      );
      const startupName =
        readString(source, "nome", "name") ?? position.startupName;
      const currentValue = position.quantity * currentPrice;

      return {
        startupId,
        startupName,
        quantity: position.quantity,
        averagePrice: position.averagePrice,
        investedAmount: position.investedAmount,
        currentPrice,
        currentValue,
        profitLoss: currentValue - position.investedAmount,
      };
    });
  }

  static async simulateDeposit(
    decodedToken: DecodedIdToken,
    input: Record<string, unknown>,
  ) {
    const rawAmount = input.amount;
    const amount = rawAmount == null ?
      DEFAULT_SIMULATED_DEPOSIT_AMOUNT :
      Number(rawAmount);

    if (!Number.isFinite(amount) || amount <= 0) {
      throw new ValidationError("amount must be a positive number");
    }

    await getOrCreateUserAccount(decodedToken);
    await creditUserBalance(decodedToken.uid, amount);

    return PortfolioService.getPortfolio(decodedToken);
  }

  private static async buildTimeline(
    positions: Array<{
      startupId: string;
      quantity: number;
      currentPrice: number;
    }>,
    startDate: Date,
  ) {
    const points = new Map<string, number>();

    await Promise.all(positions.map(async (position) => {
      try {
        const historySnapshot = await adminDb
          .collection(`startups/${position.startupId}/historicoPrecos`)
          .where("timestamp", ">=", startDate)
          .orderBy("timestamp", "asc")
          .get();

        if (historySnapshot.empty) {
          const todayKey = new Date().toISOString().slice(0, 10);
          points.set(
            todayKey,
            (points.get(todayKey) ?? 0) +
              position.quantity * position.currentPrice,
          );
          return;
        }

        historySnapshot.docs.forEach((doc) => {
          const data = doc.data();
          const timestamp = toIsoDate(data.timestamp ?? data.createdAt);
          if (!timestamp) {
            return;
          }

          const dateKey = timestamp.slice(0, 10);
          const price = readNumber(data, ["preco", "price"], 0);

          points.set(
            dateKey,
            (points.get(dateKey) ?? 0) + position.quantity * price,
          );
        });
      } catch (_error) {
        const todayKey = new Date().toISOString().slice(0, 10);
        points.set(
          todayKey,
          (points.get(todayKey) ?? 0) +
            position.quantity * position.currentPrice,
        );
      }
    }));

    return Array.from(points.entries())
      .map(([date, value]) => ({date, value}))
      .sort((left, right) => left.date.localeCompare(right.date));
  }
}
