import {FieldValue} from "firebase-admin/firestore";
import {adminDb} from "../../config/firebase-admin";
import {
  PortfolioPosition,
  getUserDocRef,
  getUserInvestmentDocRef,
} from "../users/user-account.service";

interface SeedUserInput {
  uid: string;
  email: string;
  nome?: string;
  cpf?: string;
  telefone?: string;
  mfaAtivo?: boolean;
}

interface SeedDemoInput {
  users?: SeedUserInput[];
}

const startupAId = "Xu2tL6Ap7bIzEdY4ES2r";
const startupBId = "startup_demo_health_001";

const portfolioToLegacyMap = (
  portfolio: Record<string, PortfolioPosition>,
): Record<string, Record<string, unknown>> => {
  return Object.fromEntries(
    Object.entries(portfolio).map(([startupId, position]) => [
      startupId,
      {
        startupId: position.startupId,
        startupName: position.startupName,
        quantity: position.quantity,
        averagePrice: position.averagePrice,
        investedAmount: position.investedAmount,
      },
    ]),
  );
};

const buildSeedUsers = (users: SeedUserInput[]) => {
  const firstUser = users[0] ?? {
    uid: "seed-user-a",
    email: "seed.user.a@example.com",
  };
  const secondUser = users[1] ?? {
    uid: "seed-user-b",
    email: "seed.user.b@example.com",
  };

  const startupAPortfolioUserA: Record<string, PortfolioPosition> = {
    [startupAId]: {
      startupId: startupAId,
      startupName: "Mescla Retail AI",
      quantity: 45,
      averagePrice: 10.22,
      investedAmount: 460,
    },
    [startupBId]: {
      startupId: startupBId,
      startupName: "BioPulse Health",
      quantity: 20,
      averagePrice: 15,
      investedAmount: 300,
    },
  };

  const startupAPortfolioUserB: Record<string, PortfolioPosition> = {
    [startupAId]: {
      startupId: startupAId,
      startupName: "Mescla Retail AI",
      quantity: 10,
      averagePrice: 11,
      investedAmount: 110,
    },
  };

  return [
    {
      ...firstUser,
      nome: firstUser.nome ?? "Investidor Demo A",
      cpf: firstUser.cpf ?? "11122233344",
      telefone: firstUser.telefone ?? "+55 11 99999-1001",
      mfaAtivo: firstUser.mfaAtivo ?? false,
      saldoDisponivel: 99780,
      saldoReservado: 160,
      portfolio: startupAPortfolioUserA,
    },
    {
      ...secondUser,
      nome: secondUser.nome ?? "Investidor Demo B",
      cpf: secondUser.cpf ?? "55566677788",
      telefone: secondUser.telefone ?? "+55 11 99999-2002",
      mfaAtivo: secondUser.mfaAtivo ?? true,
      saldoDisponivel: 100060,
      saldoReservado: 0,
      portfolio: startupAPortfolioUserB,
    },
  ];
};

export class DevService {
  static async seedDemoData(input: SeedDemoInput) {
    const now = new Date();
    const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    const ninetyDaysAgo = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);

    const users = buildSeedUsers(input.users ?? []);
    const [buyer, seller] = users;

    const batch = adminDb.batch();

    const startupDocs = [
      {
        id: startupAId,
        data: {
          nome: "Mescla Retail AI",
          descricao:
            "Plataforma de IA para varejo omnichannel com analytics " +
            "em tempo real.",
          estagio: "expansao",
          capitalAportado: 420000,
          totalTokens: 10000,
          tokensDisponiveis: 2500,
          valorTokenAtual: 12,
          sumarioExecutivo:
            "Startup focada em previsao de demanda, precificacao " +
            "e recomendacao inteligente.",
          planoNegociosUrl:
            "https://mesclainvest.example.com/docs/mescla-retail-ai-plano.pdf",
          pitchDeckUrl:
            "https://mesclainvest.example.com/docs/mescla-retail-ai-pitch.pdf",
          videos: [
            "https://mesclainvest.example.com/videos/mescla-retail-ai-demo.mp4",
            "https://mesclainvest.example.com/videos/" +
              "mescla-retail-ai-founder-talk.mp4",
          ],
          mentores: ["Marina Costa", "Felipe Ramos"],
          conselho: ["Ana Paula Vieira", "Ricardo Menezes"],
          variacao: {
            diaria: -4,
            semanal: 9.09,
            mensal: 20,
            seisMeses: 20,
            ytd: 20,
          },
          createdAt: ninetyDaysAgo,
          updatedAt: now,
        },
        socios: [
          {id: "socio_001", nome: "Laura Almeida", participacao: 55},
          {id: "socio_002", nome: "Bruno Nascimento", participacao: 45},
        ],
        perguntas: [
          {
            id: "pergunta_001",
            userId: buyer.uid,
            pergunta: "Qual a previsao de break-even para 2026?",
            resposta:
              "A previsao atual e atingir break-even operacional " +
              "no quarto trimestre.",
            publica: true,
            createdAt: sevenDaysAgo,
          },
          {
            id: "pergunta_002",
            userId: seller.uid,
            pergunta: "Existe plano de expansao internacional?",
            resposta: null,
            publica: false,
            createdAt: oneDayAgo,
          },
        ],
        historicoPrecos: [
          {
            id: "registro_001",
            preco: 10,
            timestamp: ninetyDaysAgo,
            origem: "seed",
            transacaoId: null,
          },
          {
            id: "registro_002",
            preco: 11,
            timestamp: thirtyDaysAgo,
            origem: "seed",
            transacaoId: null,
          },
          {
            id: "registro_003",
            preco: 12,
            timestamp: now,
            origem: "transacao",
            transacaoId: "transacao_demo_001",
          },
        ],
        atualizacoes: [
          {
            id: "atualizacao_001",
            titulo: "Nova parceria comercial",
            conteudo:
              "A startup fechou contrato com uma rede nacional de varejo.",
            tipo: "comercial",
            data: thirtyDaysAgo,
            publica: true,
          },
          {
            id: "atualizacao_002",
            titulo: "Liberacao do modulo de recomendacao",
            conteudo:
              "Novo motor de IA liberado para clientes enterprise.",
            tipo: "produto",
            data: oneDayAgo,
            publica: true,
          },
        ],
      },
      {
        id: startupBId,
        data: {
          nome: "BioPulse Health",
          descricao:
            "Healthtech para monitoramento remoto de pacientes cronicos.",
          estagio: "operacao",
          capitalAportado: 260000,
          totalTokens: 8000,
          tokensDisponiveis: 1800,
          valorTokenAtual: 16,
          sumarioExecutivo:
            "Solução SaaS+B2B para hospitais e operadoras com painel " +
            "clinico em tempo real.",
          planoNegociosUrl:
            "https://mesclainvest.example.com/docs/biopulse-health-plano.pdf",
          pitchDeckUrl:
            "https://mesclainvest.example.com/docs/biopulse-health-pitch.pdf",
          videos: [
            "https://mesclainvest.example.com/videos/biopulse-health-demo.mp4",
          ],
          mentores: ["Juliana Prado"],
          conselho: ["Carlos Tavares", "Helena Duarte"],
          variacao: {
            diaria: 1.2,
            semanal: 4.6,
            mensal: 8.4,
            seisMeses: 13.7,
            ytd: 10.1,
          },
          createdAt: ninetyDaysAgo,
          updatedAt: now,
        },
        socios: [
          {
            id: "socio_001",
            nome: "Patricia Oliveira",
            participacao: 60,
          },
          {id: "socio_002", nome: "Rafael Gomes", participacao: 40},
        ],
        perguntas: [
          {
            id: "pergunta_001",
            userId: buyer.uid,
            pergunta: "Quantos hospitais participam do piloto?",
            resposta: "Atualmente sao 12 hospitais ativos em tres estados.",
            publica: true,
            createdAt: sevenDaysAgo,
          },
        ],
        historicoPrecos: [
          {
            id: "registro_001",
            preco: 14,
            timestamp: thirtyDaysAgo,
            origem: "seed",
            transacaoId: null,
          },
          {
            id: "registro_002",
            preco: 16,
            timestamp: now,
            origem: "seed",
            transacaoId: null,
          },
        ],
        atualizacoes: [
          {
            id: "atualizacao_001",
            titulo: "Expansao do piloto clinico",
            conteudo:
              "A companhia expandiu o piloto para novas " +
              "especialidades medicas.",
            tipo: "operacional",
            data: oneDayAgo,
            publica: true,
          },
        ],
      },
    ];

    startupDocs.forEach((startup) => {
      batch.set(adminDb.collection("startups").doc(startup.id), startup.data, {
        merge: true,
      });

      startup.socios.forEach((socio) => {
        batch.set(
          adminDb.collection(`startups/${startup.id}/socios`).doc(socio.id),
          socio,
          {merge: true},
        );
      });

      startup.perguntas.forEach((pergunta) => {
        batch.set(
          adminDb
            .collection(`startups/${startup.id}/perguntas`)
            .doc(pergunta.id),
          pergunta,
          {merge: true},
        );
      });

      startup.historicoPrecos.forEach((registro) => {
        batch.set(
          adminDb
            .collection(`startups/${startup.id}/historicoPrecos`)
            .doc(registro.id),
          registro,
          {merge: true},
        );
      });

      startup.atualizacoes.forEach((atualizacao) => {
        batch.set(
          adminDb
            .collection(`startups/${startup.id}/atualizacoes`)
            .doc(atualizacao.id),
          atualizacao,
          {merge: true},
        );
      });
    });

    users.forEach((user) => {
      batch.set(
        getUserDocRef(user.uid),
        {
          nome: user.nome,
          email: user.email,
          cpf: user.cpf,
          telefone: user.telefone,
          saldoDisponivel: user.saldoDisponivel,
          saldoReservado: user.saldoReservado,
          mfaAtivo: user.mfaAtivo,
          carteira: portfolioToLegacyMap(user.portfolio),
          createdAt: ninetyDaysAgo,
          updatedAt: now,
        },
        {merge: true},
      );

      Object.values(user.portfolio).forEach((position) => {
        batch.set(
          getUserInvestmentDocRef(user.uid, position.startupId),
          {
            startupId: position.startupId,
            quantidadeTokens: position.quantity,
            precoMedio: position.averagePrice,
            valorInvestidoTotal: position.investedAmount,
            updatedAt: now,
          },
          {merge: true},
        );
      });
    });

    const offers = [
      {
        id: "oferta_demo_compra_aberta_001",
        data: {
          userId: buyer.uid,
          startupId: startupBId,
          tipo: "compra",
          quantidadeOriginal: 10,
          quantidadeRestante: 10,
          preco: 16,
          status: "aberta",
          createdAt: oneDayAgo,
          updatedAt: now,
        },
      },
      {
        id: "oferta_demo_venda_aberta_001",
        data: {
          userId: seller.uid,
          startupId: startupAId,
          tipo: "venda",
          quantidadeOriginal: 4,
          quantidadeRestante: 4,
          preco: 12.5,
          status: "aberta",
          createdAt: oneDayAgo,
          updatedAt: now,
        },
      },
      {
        id: "oferta_demo_compra_executada_001",
        data: {
          userId: buyer.uid,
          startupId: startupAId,
          tipo: "compra",
          quantidadeOriginal: 5,
          quantidadeRestante: 0,
          preco: 12,
          status: "executada",
          createdAt: thirtyDaysAgo,
          updatedAt: now,
        },
      },
      {
        id: "oferta_demo_venda_executada_001",
        data: {
          userId: seller.uid,
          startupId: startupAId,
          tipo: "venda",
          quantidadeOriginal: 5,
          quantidadeRestante: 0,
          preco: 12,
          status: "executada",
          createdAt: thirtyDaysAgo,
          updatedAt: now,
        },
      },
    ];

    offers.forEach((offer) => {
      batch.set(offersCollection.doc(offer.id), offer.data, {merge: true});
    });

    batch.set(
      transactionsCollection.doc("transacao_demo_001"),
      {
        startupId: startupAId,
        buyerId: buyer.uid,
        sellerId: seller.uid,
        quantidade: 5,
        precoUnitario: 12,
        totalValue: 60,
        ofertaCompraId: "oferta_demo_compra_executada_001",
        ofertaVendaId: "oferta_demo_venda_executada_001",
        status: "executada",
        executadaEm: now,
      },
      {merge: true},
    );

    batch.set(
      adminDb.collection("startups").doc(startupAId),
      {
        valorTokenAtual: 12,
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    await batch.commit();

    return {
      users: users.map((user) => user.uid),
      startups: startupDocs.map((startup) => startup.id),
      offers: offers.map((offer) => offer.id),
      transactionId: "transacao_demo_001",
    };
  }
}

const offersCollection = adminDb.collection("ofertas");
const transactionsCollection = adminDb.collection("transacoes");
