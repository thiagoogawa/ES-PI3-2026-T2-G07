import {adminDb} from "../../config/firebase-admin";
import {AppError} from "../../core/errors/app-error";
import {HTTP_STATUS} from "../../core/http/http-status";
import {
  readNumber,
  readRecord,
  readString,
  readStringArray,
  toIsoDate,
} from "../../utils/firestore-helpers";

interface StartupFilters {
  search?: string;
  stage?: string;
}

const startupsCollection = adminDb.collection("startups");

const normalizeStartup = (
  id: string,
  source: Record<string, unknown>,
) => {
  const name = readString(source, "nome", "name", "titulo") ?? id;
  const currentPrice = readNumber(
    source,
    [
      "valorTokenAtual",
      "precoAtual",
      "currentPrice",
      "tokenPrice",
      "valorToken",
    ],
    0,
  );
  const totalTokens = readNumber(
    source,
    ["totalTokens", "tokensEmitidos", "quantidadeTokens"],
    0,
  );
  const variation = readRecord(source, "variacao") ?? {};

  return {
    id,
    name,
    description: readString(source, "descricao", "description") ?? "",
    stage: readString(source, "estagio", "stage") ?? "Nao informado",
    sector: readString(source, "setor", "sector"),
    status: readString(source, "status"),
    capitalRaised: readNumber(
      source,
      ["capitalAportado", "capitalRaised"],
      0,
    ),
    totalTokens,
    currentPrice,
    executiveSummary: readString(
      source,
      "sumarioExecutivo",
      "executiveSummary",
    ),
    businessPlanUrl: readString(
      source,
      "planoNegociosUrl",
      "businessPlanUrl",
    ),
    pitchDeckUrl: readString(source, "pitchDeckUrl"),
    videos: readStringArray(source, "videos"),
    mentors: readStringArray(source, "mentores", "mentors"),
    boardMembers: readStringArray(source, "conselho", "boardMembers"),
    variation: {
      diaria: readNumber(variation, ["diaria"], 0),
      semanal: readNumber(variation, ["semanal"], 0),
      mensal: readNumber(variation, ["mensal"], 0),
      seisMeses: readNumber(variation, ["seisMeses"], 0),
      ytd: readNumber(variation, ["ytd"], 0),
    },
    createdAt: toIsoDate(source.createdAt),
    updatedAt: toIsoDate(source.updatedAt),
  };
};

const matchesSearch = (startupName: string, search?: string): boolean => {
  if (!search) {
    return true;
  }

  return startupName.toLowerCase().includes(search.trim().toLowerCase());
};

const matchesStage = (startupStage: string, stage?: string): boolean => {
  if (!stage) {
    return true;
  }

  return startupStage.toLowerCase() === stage.trim().toLowerCase();
};

export class StartupsService {
  static async list(filters: StartupFilters) {
    const snapshot = await startupsCollection.get();

    return snapshot.docs
      .map((doc) => normalizeStartup(doc.id, doc.data()))
      .filter((startup) => matchesSearch(startup.name, filters.search))
      .filter((startup) => matchesStage(startup.stage, filters.stage))
      .sort((left, right) => left.name.localeCompare(right.name));
  }

  static async getById(startupId: string) {
    const startupRef = startupsCollection.doc(startupId);
    const startupSnapshot = await startupRef.get();

    if (!startupSnapshot.exists) {
      throw new AppError(
        "Startup not found",
        HTTP_STATUS.NOT_FOUND,
        "STARTUP_NOT_FOUND",
      );
    }

    const startup = normalizeStartup(
      startupSnapshot.id,
      startupSnapshot.data() ?? {},
    );

    const [priceHistory, updates, partners, questions] = await Promise.all([
      StartupsService.loadPriceHistory(startupRef.path),
      StartupsService.loadUpdates(startupRef.path),
      StartupsService.loadPartners(startupRef.path),
      StartupsService.loadQuestions(startupRef.path),
    ]);

    return {
      ...startup,
      documents: {
        executiveSummary: startup.executiveSummary,
        businessPlanUrl: startup.businessPlanUrl,
        pitchDeckUrl: startup.pitchDeckUrl,
      },
      metrics: {
        capitalRaised: startup.capitalRaised,
        totalTokens: startup.totalTokens,
        currentPrice: startup.currentPrice,
        marketCap:
          startup.currentPrice > 0 && startup.totalTokens > 0 ?
            startup.currentPrice * startup.totalTokens :
            null,
      },
      socios: partners,
      perguntas: questions,
      updates,
      priceHistory,
    };
  }

  private static async loadPriceHistory(startupPath: string) {
    try {
      const snapshot = await adminDb
        .collection(`${startupPath}/historicoPrecos`)
        .get();

      return snapshot.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          price: readNumber(data, ["preco", "price"], 0),
          timestamp: toIsoDate(data.timestamp ?? data.createdAt),
          source: readString(data, "origem", "source"),
          transactionId: readString(data, "transacaoId"),
        };
      }).sort((left, right) => {
        return (right.timestamp ?? "").localeCompare(left.timestamp ?? "");
      }).slice(0, 30);
    } catch (_error) {
      return [];
    }
  }

  private static async loadUpdates(startupPath: string) {
    try {
      const snapshot = await adminDb
        .collection(`${startupPath}/atualizacoes`)
        .get();

      return snapshot.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          title: readString(data, "titulo", "title") ?? "Atualizacao",
          content: readString(data, "conteudo", "content") ?? "",
          type: readString(data, "tipo", "type"),
          public: data.publica === false ? false : true,
          date: toIsoDate(data.data ?? data.createdAt),
        };
      }).sort((left, right) => {
        return (right.date ?? "").localeCompare(left.date ?? "");
      }).slice(0, 10);
    } catch (_error) {
      return [];
    }
  }

  private static async loadPartners(startupPath: string) {
    try {
      const snapshot = await adminDb.collection(`${startupPath}/socios`).get();

      return snapshot.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          nome: readString(data, "nome") ?? "Socio",
          participacao: readNumber(data, ["participacao"], 0),
        };
      }).sort((left, right) => right.participacao - left.participacao);
    } catch (_error) {
      return [];
    }
  }

  private static async loadQuestions(startupPath: string) {
    try {
      const snapshot = await adminDb
        .collection(`${startupPath}/perguntas`)
        .get();

      return snapshot.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          userId: readString(data, "userId") ?? "",
          pergunta: readString(data, "pergunta") ?? "",
          resposta: readString(data, "resposta"),
          publica: data.publica === false ? false : true,
          createdAt: toIsoDate(data.createdAt),
        };
      }).filter((item) => item.publica).sort((left, right) => {
        return (right.createdAt ?? "").localeCompare(left.createdAt ?? "");
      });
    } catch (_error) {
      return [];
    }
  }
}
