# 📱 MesclaInvest | PI3-2026-T2-G07

<img width="1365" height="768" alt="MesclaInvest" src="https://github.com/user-attachments/assets/3b778408-01c9-4505-a77d-75ded48212be" />


O **MesclaInvest** é um aplicativo de investimentos mobile, desenvolvido como parte do **Projeto Integrador 3 (PI3) – 2026** do curso de Engenharia de Software da **PUC-Campinas**.

A plataforma simula a negociação de tokens representativos de startups, permitindo que usuários entendam a dinâmica de aportes e valorização em um ambiente controlado.

## 👥 Integrantes
- CAIO JOSÉ BURDIM MENALI (Frontend) - RA: 25013468    
- LUCCA SCHROELDER SCOVINI (Frontend) - RA: 24011609  
- PAULO CESAR WHITEHEAD JUNIOR (Banco de dados/Backend) - RA: 24018776  
- THIAGO RYUJI OGAWA (Infra/Backend)- RA: 24024450  

## 🧰 Tecnologias Utilizadas
**Backend** | Node.js (LTS), TypeScript, Firebase Firestore |  
**Mobile** | Flutter, Dart |  
**Ferramentas** | Git, GitHub, GitHub Projects, VS Code / Android Studio |  

---

## 🎯 Funcionalidades

### Autenticação

- Cadastro de usuários com e-mail, CPF, telefone e senha
- Login seguro com recuperação de senha

### Catálogo de Startups

- Visualização de startups cadastradas no ecossistema
- Informações detalhadas: descrição, estrutura societária, capital aportado
- Filtros por estágio de desenvolvimento (Nova ideia, Em operação, Em expansão)
- Acesso a documentos: sumário executivo, plano de negócios, vídeos demo

### Negociação Simulada de Tokens

- Balcão de compra/venda de tokens (simulado)
- Carteira digital com saldo fictício em reais
- Ofertas de compra/venda entre usuários cadastrados
- Compra e venda diretamente na página da startup, com matching automático no book

### Dashboard de Investimentos

- Acompanhamento de valorização dos tokens
- Gráficos de variação (diário, semanal, mensal, YTD)
- Cálculo de tendências baseado em transações simuladas

### Interação com Startups

- Envio de perguntas públicas/privadas aos empreendedores
- Feed de atualizações e eventos das startups

---

## 🔁 Fluxo De Compra E Venda

O fluxo de negociação segue o PDF do projeto:

- Compra e venda simuladas de tokens dentro do app
- Execução direta na página da startup
- Balcão com ofertas abertas de compra e venda
- Atualização de saldo, carteira, transações e histórico de preço a cada execução

### Functions HTTP usadas pelo mobile

- `GET /v1/startups/:startupId`: detalhes da startup, preço atual e histórico
- `GET /v1/offers?startupId=:startupId`: book de ofertas da startup
- `GET /v1/portfolio`: saldo fictício, saldo reservado e posição do investidor
- `POST /v1/startups/:startupId/trade`: envia ordem direta de compra/venda e faz matching automático
- `POST /v1/offers/:offerId/accept`: aceita uma oferta aberta do book

### Comportamento do endpoint de trade direto

O endpoint `POST /v1/startups/:startupId/trade`:

- recebe `type`, `quantity` e `pricePerToken`
- procura ofertas opostas compatíveis no book da startup
- executa os matches possíveis pelo melhor preço disponível
- deixa a quantidade restante como oferta aberta, quando houver sobra

---

## ⚙️ Backend E Deploy

O backend de Cloud Functions está em [backend/functions](/Users/thiagoogawa/Documents/PUC%204%20semestre/PII%203%20-%20Mobile/ES-PI3-2026-T2-G07/backend/functions) e usa Firestore nomeado `mescla-inv`.

### Rodar localmente

No diretório [backend](/Users/thiagoogawa/Documents/PUC%204%20semestre/PII%203%20-%20Mobile/ES-PI3-2026-T2-G07/backend):

```bash
FIRESTORE_DATABASE_ID=mescla-inv npm --prefix functions run serve
```

Isso sobe o emulador das functions com build e lint configurados no `firebase.json`.

### Deploy das functions

No diretório [backend](/Users/thiagoogawa/Documents/PUC%204%20semestre/PII%203%20-%20Mobile/ES-PI3-2026-T2-G07/backend):

```bash
npm --prefix functions run deploy -- --project <firebase-project-id>
```

Se quiser validar antes do deploy:

```bash
npm --prefix functions run lint
npm --prefix functions run build
```

### Base URL do mobile

Ambiente local:

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5001/<firebase-project-id>/us-central1/api
```

Em dispositivo Android usando o emulador, ajuste o host para `10.0.2.2` se necessário.

Ambiente deployado:

```bash
flutter run --dart-define=API_BASE_URL=https://us-central1-<firebase-project-id>.cloudfunctions.net/api
```

---



