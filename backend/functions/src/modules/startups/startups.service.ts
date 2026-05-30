/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Service do modulo de startups.
 * Concentra regras de negocio, acesso a dados e validacoes
 * necessarias antes de responder aos endpoints da API.
 */

import {adminDb} from "../../config/firebase-admin";
import {AppError} from "../../core/errors/app-error";
import {AuthError} from "../../core/errors/auth-error";
import {ValidationError} from "../../core/errors/validation-error";
import {HTTP_STATUS} from "../../core/http/http-status";
import {DecodedIdToken} from "firebase-admin/auth";
import {FieldValue} from "firebase-admin/firestore";
import {getOrCreateUserAccount} from "../users/user-account.service";
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
    photoUrl: readString(source, "fotoUrl", "photoUrl", "imageUrl", "logoUrl"),
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

  static async listManagedByUser(userId: string) {
    const [adminUidSnapshot, adminSnapshot] = await Promise.all([
      startupsCollection.where("adminUid", "==", userId).get(),
      startupsCollection.where("admin.uid", "==", userId).get(),
    ]);

    const uniqueDocs = new Map<string, FirebaseFirestore.QueryDocumentSnapshot>();

    [...adminUidSnapshot.docs, ...adminSnapshot.docs].forEach((doc) => {
      uniqueDocs.set(doc.id, doc);
    });

    return Array.from(uniqueDocs.values())
      .map((doc) => normalizeStartup(doc.id, doc.data()))
      .sort((left, right) => left.name.localeCompare(right.name));
  }

  static async getById(startupId: string, viewer?: DecodedIdToken) {
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
    const canViewPrivateQuestions = await StartupsService.canViewPrivateQuestions(
      startupId,
      startupSnapshot.data() ?? {},
      viewer,
    );

    const [priceHistory, updates, partners, questions] = await Promise.all([
      StartupsService.loadPriceHistory(startupRef.path),
      StartupsService.loadUpdates(startupRef.path),
      StartupsService.loadPartners(startupRef.path),
      StartupsService.loadQuestions(startupRef.path, viewer, {
        includePrivate: canViewPrivateQuestions,
      }),
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

  static async updateStartup(
    startupId: string,
    user: DecodedIdToken,
    input: Record<string, unknown>,
  ) {
    const startupRef = await StartupsService.assertAdminAccess(startupId, user);
    const payload = StartupsService.buildStartupUpdatePayload(input);

    await startupRef.set(
      {
        ...payload,
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    return StartupsService.getById(startupId);
  }

  static async answerQuestion(
    startupId: string,
    questionId: string,
    user: DecodedIdToken,
    input: Record<string, unknown>,
  ) {
    const startupRef = await StartupsService.assertAdminAccess(startupId, user);
    const questionRef = startupRef.collection("perguntas").doc(questionId);
    const questionSnapshot = await questionRef.get();

    if (!questionSnapshot.exists) {
      throw new AppError(
        "Question not found",
        HTTP_STATUS.NOT_FOUND,
        "QUESTION_NOT_FOUND",
      );
    }

    const answer = String(input.answer ?? "").trim();
    if (!answer) {
      throw new ValidationError("answer is required");
    }

    if (answer.length > 1000) {
      throw new ValidationError("answer must contain at most 1000 characters");
    }

    await questionRef.set(
      {
        resposta: answer,
        updatedAt: new Date().toISOString(),
      },
      {merge: true},
    );

    return StartupsService.getById(startupId, user);
  }

  static async submitQuestion(
    startupId: string,
    user: DecodedIdToken | undefined,
    input: {question?: unknown; authorName?: unknown; public?: unknown},
  ) {
    const startupRef = startupsCollection.doc(startupId);
    const startupSnapshot = await startupRef.get();

    if (!startupSnapshot.exists) {
      throw new AppError(
        "Startup not found",
        HTTP_STATUS.NOT_FOUND,
        "STARTUP_NOT_FOUND",
      );
    }

    const question = String(input.question ?? "").trim();
    const authorName = String(input.authorName ?? "").trim();
    const isPublic = input.public === false ? false : true;

    if (!question) {
      throw new ValidationError("question is required");
    }

    if (question.length < 8) {
      throw new ValidationError("question must contain at least 8 characters");
    }

    if (question.length > 280) {
      throw new ValidationError("question must contain at most 280 characters");
    }

    if (authorName.length > 80) {
      throw new ValidationError("authorName must contain at most 80 characters");
    }

    if (!isPublic) {
      if (!user) {
        throw new AuthError("Authentication required for private questions");
      }

      const isInvestor = await StartupsService.isInvestorInStartup(
        startupId,
        user,
      );

      if (!isInvestor) {
        throw new AuthError(
          "Only startup investors can send private questions",
          "PRIVATE_QUESTION_REQUIRES_INVESTOR",
        );
      }
    }

    const questionRef = startupRef.collection("perguntas").doc();
    const now = new Date().toISOString();
    const userId = user?.uid ?? "anonymous";

    await questionRef.set({
      pergunta: question,
      resposta: "",
      publica: isPublic,
      userId,
      autorNome: authorName || null,
      createdAt: now,
      updatedAt: now,
    });

    return {
      id: questionRef.id,
      pergunta: question,
      resposta: "",
      publica: isPublic,
      userId,
      autorNome: authorName || null,
      createdAt: now,
      updatedAt: now,
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
      });
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

  private static async loadQuestions(
    startupPath: string,
    viewer?: DecodedIdToken,
    options: {includePrivate?: boolean} = {},
  ) {
    try {
      const snapshot = await adminDb
        .collection(`${startupPath}/perguntas`)
        .get();

      return snapshot.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          userId: readString(data, "userId") ?? "",
          autorNome: readString(data, "autorNome"),
          pergunta: readString(data, "pergunta") ?? "",
          resposta: readString(data, "resposta"),
          publica: data.publica === false ? false : true,
          createdAt: toIsoDate(data.createdAt),
        };
      }).filter((item) => {
        if (item.publica) {
          return true;
        }

        if (options.includePrivate) {
          return true;
        }

        return Boolean(viewer && item.userId == viewer.uid);
      }).sort((left, right) => {
        return (right.createdAt ?? "").localeCompare(left.createdAt ?? "");
      });
    } catch (_error) {
      return [];
    }
  }

  private static async canViewPrivateQuestions(
    startupId: string,
    startupData: Record<string, unknown>,
    viewer?: DecodedIdToken,
  ) {
    if (!viewer) {
      return false;
    }

    if (StartupsService.isStartupAdmin(startupData, viewer.uid)) {
      return true;
    }

    return StartupsService.isInvestorInStartup(startupId, viewer);
  }

  private static isStartupAdmin(
    startupData: Record<string, unknown>,
    uid: string,
  ) {
    const adminUid = readString(startupData, "adminUid");
    const admin = readRecord(startupData, "admin") ?? {};

    return adminUid === uid || readString(admin, "uid") === uid;
  }

  private static async isInvestorInStartup(
    startupId: string,
    user: DecodedIdToken,
  ) {
    const account = await getOrCreateUserAccount(user);
    const position = account.portfolio[startupId];

    return (position?.quantity ?? 0) > 0;
  }

  private static buildStartupUpdatePayload(input: Record<string, unknown>) {
    const name = String(input.name ?? "").trim();
    const description = String(input.description ?? "").trim();
    const stage = String(input.stage ?? "").trim();
    const sector = String(input.sector ?? "").trim();
    const photoUrl = String(input.photoUrl ?? input.imageUrl ?? "").trim();
    const executiveSummary = String(input.executiveSummary ?? "").trim();
    const businessPlanUrl = String(input.businessPlanUrl ?? "").trim();
    const pitchDeckUrl = String(input.pitchDeckUrl ?? "").trim();
    const mentors = StartupsService.toStringList(input.mentors);
    const boardMembers = StartupsService.toStringList(input.boardMembers);
    const videos = StartupsService.toStringList(input.videos);

    if (!name) {
      throw new ValidationError("name is required");
    }

    if (!description) {
      throw new ValidationError("description is required");
    }

    if (!stage) {
      throw new ValidationError("stage is required");
    }

    return {
      nome: name,
      descricao: description,
      estagio: stage,
      setor: sector || null,
      fotoUrl: photoUrl || null,
      sumarioExecutivo: executiveSummary,
      planoNegociosUrl: businessPlanUrl || null,
      pitchDeckUrl: pitchDeckUrl || null,
      mentores: mentors,
      conselho: boardMembers,
      videos,
    };
  }

  private static toStringList(value: unknown): string[] {
    if (!Array.isArray(value)) {
      return [];
    }

    return value
      .filter((item): item is string => typeof item === "string")
      .map((item) => item.trim())
      .filter(Boolean);
  }

  private static async assertAdminAccess(
    startupId: string,
    user: DecodedIdToken,
  ) {
    const startupRef = startupsCollection.doc(startupId);
    const startupSnapshot = await startupRef.get();

    if (!startupSnapshot.exists) {
      throw new AppError(
        "Startup not found",
        HTTP_STATUS.NOT_FOUND,
        "STARTUP_NOT_FOUND",
      );
    }

    const source = startupSnapshot.data() ?? {};
    const adminUid = readString(source, "adminUid");
    const admin = readRecord(source, "admin");
    const nestedAdminUid = admin ? readString(admin, "uid") : null;

    if (adminUid !== user.uid && nestedAdminUid !== user.uid) {
      throw new AuthError(
        "User is not allowed to manage this startup",
        "STARTUP_ADMIN_REQUIRED",
      );
    }

    return startupRef;
  }
}
