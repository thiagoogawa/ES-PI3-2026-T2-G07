/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Service do modulo de desenvolvimento.
 * Concentra regras de negocio, acesso a dados e validacoes
 * necessarias antes de responder aos endpoints da API.
 */

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

/**
 * Estrutura minima aceita para criar usuarios de demonstração.
 */

const startupAId = "Xu2tL6Ap7bIzEdY4ES2r";
const startupBId = "startup_demo_health_001";

const storageBucket = "mesclainvest-dev.firebasestorage.app";
const genericStartupPhotoUrl =
  `https://firebasestorage.googleapis.com/v0/b/${storageBucket}/o/` +
  `imagens%2Fstartups%2Fstartup-generic.svg?alt=media&token=` +
  "4c8256ef-1962-4e55-a264-4e1ac4a1aa08";

const startupPhotoUrls: Record<string, string> = {
  [startupAId]:
    `https://firebasestorage.googleapis.com/v0/b/${storageBucket}/o/` +
    `imagens%2Fstartups%2Fmescla-retail-ai.svg?alt=media&token=` +
    "4b1a95c6-41d2-4f3c-8c0e-12ee3d55aa01",
  [startupBId]:
    `https://firebasestorage.googleapis.com/v0/b/${storageBucket}/o/` +
    `imagens%2Fstartups%2Fbiopulse-health.svg?alt=media&token=` +
    "1e2bb8d7-1228-4ef5-9ac8-b4de0d91aa02",
  startup_demo_climate_001:
    `https://firebasestorage.googleapis.com/v0/b/${storageBucket}/o/` +
    `imagens%2Fstartups%2Fverdeloop-carbon.svg?alt=media&token=` +
    "f77b8eed-b8dc-468e-b802-a6f3b86baa03",
  startup_demo_finance_001:
    `https://firebasestorage.googleapis.com/v0/b/${storageBucket}/o/` +
    `imagens%2Fstartups%2Fatlas-finops.svg?alt=media&token=` +
    "157a1f2e-b612-4fce-aeb5-38db16f6aa04",
  startup_demo_logistics_001:
    `https://firebasestorage.googleapis.com/v0/b/${storageBucket}/o/` +
    `imagens%2Fstartups%2Forbit-cargo.svg?alt=media&token=` +
    "6c1f5d45-3020-4b11-8f7d-3bcb5790aa05",
  startup_demo_edtech_001:
    `https://firebasestorage.googleapis.com/v0/b/${storageBucket}/o/` +
    `imagens%2Fstartups%2Flumina-edtech.svg?alt=media&token=` +
    "2a1e96d3-6ab1-4703-ab8f-82a2dd5daa06",
  startup_demo_energy_001:
    `https://firebasestorage.googleapis.com/v0/b/${storageBucket}/o/` +
    `imagens%2Fstartups%2Fsolis-grid.svg?alt=media&token=` +
    "8f4f2384-a2c7-4126-b4f7-bb8dd527aa07",
};

const buildStartupPhotoUrl = (id: string) => {
  return startupPhotoUrls[id] ?? genericStartupPhotoUrl;
};

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

/**
 * Concentra a preparação de dados demo usados em ambiente local e homologação.
 */
export class DevService {
  /**
  * Cria ou atualiza usuários, startups e documentos relacionados com dados de
  * demonstração para facilitar testes manuais do sistema.
  */
  static async seedDemoData(input: SeedDemoInput) {
    const now = new Date();
    const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    const ninetyDaysAgo = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);

    const users = buildSeedUsers(input.users ?? []);
    const [buyer, seller] = users;
    const existingStartupsSnapshot = await adminDb.collection("startups").get();

    const batch = adminDb.batch();

    const startupDocs = [
      {
        id: startupAId,
        data: {
          nome: "Mescla Retail AI",
          fotoUrl: buildStartupPhotoUrl(startupAId),
          descricao:
            "Plataforma de IA para varejo omnichannel com analytics " +
            "em tempo real.",
          estagio: "expansao",
          setor: "operacao",
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
          fotoUrl: buildStartupPhotoUrl(startupBId),
          descricao:
            "Healthtech para monitoramento remoto de pacientes cronicos.",
          estagio: "operacao",
          setor: "saude",
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
      {
        id: "startup_demo_climate_001",
        data: {
          nome: "VerdeLoop Carbon",
          fotoUrl: buildStartupPhotoUrl("startup_demo_climate_001"),
          descricao:
            "Climate tech para rastreamento de carbono e monetizacao de creditos ambientais.",
          estagio: "tracao",
          setor: "climate tech",
          capitalAportado: 310000,
          totalTokens: 9000,
          tokensDisponiveis: 2200,
          valorTokenAtual: 9.4,
          sumarioExecutivo:
            "Plataforma que integra inventario ESG, auditoria automatizada e marketplace de creditos.",
          planoNegociosUrl:
            "https://mesclainvest.example.com/docs/verdeloop-carbon-plano.pdf",
          pitchDeckUrl:
            "https://mesclainvest.example.com/docs/verdeloop-carbon-pitch.pdf",
          videos: [
            "https://mesclainvest.example.com/videos/verdeloop-carbon-demo.mp4",
          ],
          mentores: ["Tatiana Neves", "Rodrigo Pires"],
          conselho: ["Marcelo Teixeira"],
          variacao: {
            diaria: 2.1,
            semanal: 5.8,
            mensal: 11.4,
            seisMeses: 18.2,
            ytd: 14.9,
          },
          createdAt: ninetyDaysAgo,
          updatedAt: now,
        },
        socios: [
          {id: "socio_001", nome: "Camila Azevedo", participacao: 58},
          {id: "socio_002", nome: "Diego Luz", participacao: 42},
        ],
        perguntas: [
          {
            id: "pergunta_001",
            userId: buyer.uid,
            pergunta: "Qual o volume anual de ativos monitorados?",
            resposta: "Mais de 1,8 milhao de toneladas ja passam pela plataforma.",
            publica: true,
            createdAt: sevenDaysAgo,
          },
        ],
        historicoPrecos: [
          {
            id: "registro_001",
            preco: 8.1,
            timestamp: ninetyDaysAgo,
            origem: "seed",
            transacaoId: null,
          },
          {
            id: "registro_002",
            preco: 8.8,
            timestamp: thirtyDaysAgo,
            origem: "seed",
            transacaoId: null,
          },
          {
            id: "registro_003",
            preco: 9.4,
            timestamp: now,
            origem: "seed",
            transacaoId: null,
          },
        ],
        atualizacoes: [
          {
            id: "atualizacao_001",
            titulo: "Nova integracao com ERPs industriais",
            conteudo:
              "A startup passou a consolidar dados de emissao direto de operacoes fabris.",
            tipo: "produto",
            data: oneDayAgo,
            publica: true,
          },
        ],
      },
      {
        id: "startup_demo_finance_001",
        data: {
          nome: "Atlas FinOps",
          fotoUrl: buildStartupPhotoUrl("startup_demo_finance_001"),
          descricao:
            "Fintech B2B para gestao de caixa, cobranca e conciliacao automatizada para PMEs.",
          estagio: "expansao",
          setor: "fintech",
          capitalAportado: 540000,
          totalTokens: 12000,
          tokensDisponiveis: 3600,
          valorTokenAtual: 13.7,
          sumarioExecutivo:
            "Motor financeiro com regras configuraveis para previsao de caixa e recuperacao de inadimplencia.",
          planoNegociosUrl:
            "https://mesclainvest.example.com/docs/atlas-finops-plano.pdf",
          pitchDeckUrl:
            "https://mesclainvest.example.com/docs/atlas-finops-pitch.pdf",
          videos: [
            "https://mesclainvest.example.com/videos/atlas-finops-demo.mp4",
          ],
          mentores: ["Sergio Moraes"],
          conselho: ["Mariana Lopes", "Gustavo Faria"],
          variacao: {
            diaria: -1.4,
            semanal: 3.2,
            mensal: 6.5,
            seisMeses: 15.1,
            ytd: 12.3,
          },
          createdAt: ninetyDaysAgo,
          updatedAt: now,
        },
        socios: [
          {id: "socio_001", nome: "Brenda Sales", participacao: 62},
          {id: "socio_002", nome: "Icaro Motta", participacao: 38},
        ],
        perguntas: [
          {
            id: "pergunta_001",
            userId: seller.uid,
            pergunta: "Qual a taxa media de inadimplencia apos o onboarding?",
            resposta: "Clientes ativos reduzem em media 23% da inadimplencia em 90 dias.",
            publica: true,
            createdAt: oneDayAgo,
          },
        ],
        historicoPrecos: [
          {
            id: "registro_001",
            preco: 12.2,
            timestamp: ninetyDaysAgo,
            origem: "seed",
            transacaoId: null,
          },
          {
            id: "registro_002",
            preco: 13.1,
            timestamp: thirtyDaysAgo,
            origem: "seed",
            transacaoId: null,
          },
          {
            id: "registro_003",
            preco: 13.7,
            timestamp: now,
            origem: "seed",
            transacaoId: null,
          },
        ],
        atualizacoes: [
          {
            id: "atualizacao_001",
            titulo: "Motor de cobranca preditiva liberado",
            conteudo:
              "A companhia ativou um modulo de cobranca com segmentacao por risco.",
            tipo: "produto",
            data: sevenDaysAgo,
            publica: true,
          },
        ],
      },
      {
        id: "startup_demo_logistics_001",
        data: {
          nome: "Orbit Cargo",
          fotoUrl: buildStartupPhotoUrl("startup_demo_logistics_001"),
          descricao:
            "Logtech de roteirizacao dinamica e consolidacao de cargas urbanas para e-commerce.",
          estagio: "operacao",
          setor: "logistica",
          capitalAportado: 470000,
          totalTokens: 11000,
          tokensDisponiveis: 3100,
          valorTokenAtual: 11.2,
          sumarioExecutivo:
            "Camada operacional para reduzir ociosidade de frota e aumentar previsibilidade de entregas.",
          planoNegociosUrl:
            "https://mesclainvest.example.com/docs/orbit-cargo-plano.pdf",
          pitchDeckUrl:
            "https://mesclainvest.example.com/docs/orbit-cargo-pitch.pdf",
          videos: [
            "https://mesclainvest.example.com/videos/orbit-cargo-demo.mp4",
          ],
          mentores: ["Rita Muniz"],
          conselho: ["Alexandre Paiva", "Nadia Ferraz"],
          variacao: {
            diaria: 0.9,
            semanal: 2.4,
            mensal: 7.1,
            seisMeses: 9.8,
            ytd: 8.5,
          },
          createdAt: ninetyDaysAgo,
          updatedAt: now,
        },
        socios: [
          {id: "socio_001", nome: "Henrique Campos", participacao: 51},
          {id: "socio_002", nome: "Priscila Melo", participacao: 49},
        ],
        perguntas: [
          {
            id: "pergunta_001",
            userId: buyer.uid,
            pergunta: "Qual foi a reducao media no custo por entrega?",
            resposta: "A media consolidada esta em 17% nas operacoes recorrentes.",
            publica: true,
            createdAt: sevenDaysAgo,
          },
        ],
        historicoPrecos: [
          {
            id: "registro_001",
            preco: 10.4,
            timestamp: ninetyDaysAgo,
            origem: "seed",
            transacaoId: null,
          },
          {
            id: "registro_002",
            preco: 10.9,
            timestamp: thirtyDaysAgo,
            origem: "seed",
            transacaoId: null,
          },
          {
            id: "registro_003",
            preco: 11.2,
            timestamp: now,
            origem: "seed",
            transacaoId: null,
          },
        ],
        atualizacoes: [
          {
            id: "atualizacao_001",
            titulo: "Expansao para hubs regionais",
            conteudo:
              "A malha logistica passou a operar em dois novos hubs urbanos.",
            tipo: "operacional",
            data: oneDayAgo,
            publica: true,
          },
        ],
      },
      {
        id: "startup_demo_edtech_001",
        data: {
          nome: "Lumina EdTech",
          fotoUrl: buildStartupPhotoUrl("startup_demo_edtech_001"),
          descricao:
            "Edtech com trilhas adaptativas para formacao tecnica e onboarding corporativo.",
          estagio: "tracao",
          setor: "educacao",
          capitalAportado: 280000,
          totalTokens: 7000,
          tokensDisponiveis: 1900,
          valorTokenAtual: 8.6,
          sumarioExecutivo:
            "Ambiente de aprendizagem com motor adaptativo e analytics de progresso em tempo real.",
          planoNegociosUrl:
            "https://mesclainvest.example.com/docs/lumina-edtech-plano.pdf",
          pitchDeckUrl:
            "https://mesclainvest.example.com/docs/lumina-edtech-pitch.pdf",
          videos: [
            "https://mesclainvest.example.com/videos/lumina-edtech-demo.mp4",
          ],
          mentores: ["Claudia Freitas"],
          conselho: ["Fernando Rocha"],
          variacao: {
            diaria: 3.4,
            semanal: 6.8,
            mensal: 10.6,
            seisMeses: 16.9,
            ytd: 15.7,
          },
          createdAt: ninetyDaysAgo,
          updatedAt: now,
        },
        socios: [
          {id: "socio_001", nome: "Renata Peixoto", participacao: 64},
          {id: "socio_002", nome: "Thiago Bernardes", participacao: 36},
        ],
        perguntas: [
          {
            id: "pergunta_001",
            userId: seller.uid,
            pergunta: "Quantos alunos corporativos usam a plataforma?",
            resposta: "A base ativa superou 48 mil usuarios no ultimo trimestre.",
            publica: true,
            createdAt: oneDayAgo,
          },
        ],
        historicoPrecos: [
          {
            id: "registro_001",
            preco: 7.4,
            timestamp: ninetyDaysAgo,
            origem: "seed",
            transacaoId: null,
          },
          {
            id: "registro_002",
            preco: 8.0,
            timestamp: thirtyDaysAgo,
            origem: "seed",
            transacaoId: null,
          },
          {
            id: "registro_003",
            preco: 8.6,
            timestamp: now,
            origem: "seed",
            transacaoId: null,
          },
        ],
        atualizacoes: [
          {
            id: "atualizacao_001",
            titulo: "Nova trilha para operacoes industriais",
            conteudo:
              "Foi liberado um pacote de cursos tecnicos voltado a times de manufatura.",
            tipo: "conteudo",
            data: sevenDaysAgo,
            publica: true,
          },
        ],
      },
      {
        id: "startup_demo_energy_001",
        data: {
          nome: "Solis Grid",
          fotoUrl: buildStartupPhotoUrl("startup_demo_energy_001"),
          descricao:
            "Energy tech para gestao de microredes solares e previsao de consumo em condominios e empresas.",
          estagio: "expansao",
          setor: "energia",
          capitalAportado: 630000,
          totalTokens: 15000,
          tokensDisponiveis: 4700,
          valorTokenAtual: 14.3,
          sumarioExecutivo:
            "Infraestrutura de software para orquestrar geracao distribuida, armazenamento e eficiencia energetica.",
          planoNegociosUrl:
            "https://mesclainvest.example.com/docs/solis-grid-plano.pdf",
          pitchDeckUrl:
            "https://mesclainvest.example.com/docs/solis-grid-pitch.pdf",
          videos: [
            "https://mesclainvest.example.com/videos/solis-grid-demo.mp4",
          ],
          mentores: ["Vicente Braga", "Paula Arantes"],
          conselho: ["Cristiane Nogueira"],
          variacao: {
            diaria: -0.6,
            semanal: 4.4,
            mensal: 9.7,
            seisMeses: 17.6,
            ytd: 13.8,
          },
          createdAt: ninetyDaysAgo,
          updatedAt: now,
        },
        socios: [
          {id: "socio_001", nome: "Leandro Couto", participacao: 57},
          {id: "socio_002", nome: "Monica Reis", participacao: 43},
        ],
        perguntas: [
          {
            id: "pergunta_001",
            userId: buyer.uid,
            pergunta: "Qual a capacidade instalada gerenciada?",
            resposta: "A operacao monitora 86 MW em ativos distribuidos.",
            publica: true,
            createdAt: sevenDaysAgo,
          },
        ],
        historicoPrecos: [
          {
            id: "registro_001",
            preco: 12.9,
            timestamp: ninetyDaysAgo,
            origem: "seed",
            transacaoId: null,
          },
          {
            id: "registro_002",
            preco: 13.6,
            timestamp: thirtyDaysAgo,
            origem: "seed",
            transacaoId: null,
          },
          {
            id: "registro_003",
            preco: 14.3,
            timestamp: now,
            origem: "seed",
            transacaoId: null,
          },
        ],
        atualizacoes: [
          {
            id: "atualizacao_001",
            titulo: "Primeira microrede comercial entregue",
            conteudo:
              "O time concluiu a implantacao completa da primeira microrede multiunidade.",
            tipo: "implantacao",
            data: oneDayAgo,
            publica: true,
          },
        ],
      },
    ];

    existingStartupsSnapshot.docs.forEach((doc) => {
      const source = doc.data();
      const hasPhoto =
        typeof source.fotoUrl === "string" ||
        typeof source.photoUrl === "string" ||
        typeof source.imageUrl === "string" ||
        typeof source.logoUrl === "string";

      if (hasPhoto) {
        return;
      }

      batch.set(
        doc.ref,
        {
          fotoUrl: buildStartupPhotoUrl(doc.id),
          updatedAt: now,
        },
        {merge: true},
      );
    });

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
