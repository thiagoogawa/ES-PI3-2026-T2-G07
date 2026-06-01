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

## 🗂️ Estrutura Do Repositório

- `backend/`: configuração Firebase, regras de Storage e Cloud Functions
- `backend/functions/`: API em Node.js + TypeScript
- `mobile/`: aplicativo Flutter
- `docs/`: materiais de apoio, atas e artefatos de documentação

---

## ⚙️ Como Executar Em Ambiente De Testes

Esta seção atende ao requisito do PDF de fornecer instruções claras para execução do sistema.

### 1. Pré-requisitos

Antes de executar o projeto, instale e configure:

- Node.js `24.x` ou compatível com o valor definido em `backend/functions/package.json`
- npm
- Flutter SDK compatível com Dart `^3.11.0`
- Firebase CLI (`npm install -g firebase-tools`)
- Android Studio ou VS Code com SDK Android configurado
- Um emulador Android, dispositivo Android físico, ou Chrome/macOS para testes do app

### 2. Configurações já presentes no projeto

- O app mobile já possui `firebase_options.dart` configurado para o projeto Firebase `mesclainvest-dev`
- O `google-services.json` do Android já está versionado em `mobile/android/app/`
- O backend utiliza o banco Firestore nomeado `mescla-inv`
- A API local é exposta pelo emulador de Functions na porta `5001`

### 3. Instalar dependências

#### Backend

No diretório raiz do projeto:

```bash
cd backend/functions
npm install
```

#### Mobile

No diretório raiz do projeto:

```bash
cd mobile
flutter pub get
```

### 4. Subir o backend local

No diretório `backend/`:

```bash
cd backend
FIRESTORE_DATABASE_ID=mescla-inv npm --prefix functions run serve
```

Esse comando:

- compila o TypeScript
- executa o lint do backend no predeploy configurado
- sobe o emulador de Cloud Functions

### 5. Verificar se a API local está saudável

Após subir o backend, teste o endpoint de health:

```bash
curl http://127.0.0.1:5001/mesclainvest-dev/us-central1/api/health
```

Resposta esperada:

```json
{
	"success": true,
	"message": "API is healthy",
	"data": {
		"status": "ok"
	}
}
```

### 6. Executar o app mobile apontando para a API local

No diretório `mobile/`, rode um dos comandos abaixo.

#### Android Emulator

```bash
cd mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5001/mesclainvest-dev/us-central1/api
```

#### iOS Simulator, macOS ou Chrome

```bash
cd mobile
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5001/mesclainvest-dev/us-central1/api
```

#### Dispositivo Android físico

Use o IP da máquina que está executando o backend, por exemplo:

```bash
cd mobile
flutter run --dart-define=API_BASE_URL=http://192.168.0.10:5001/mesclainvest-dev/us-central1/api
```

### 7. Fluxo mínimo para validar o sistema

Depois que backend e mobile estiverem rodando:

1. criar conta com nome, CPF, telefone, e-mail e senha
2. fazer login
3. acessar a home e conferir o catálogo de startups
4. consultar detalhes da startup, FAQ e documentos informativos
5. depositar saldo fictício
6. enviar ordem de compra ou venda no balcão
7. acompanhar a atualização da carteira e da valorização dos tokens
8. opcionalmente ativar 2FA em `Acesso e segurança`

---

## 🧪 Comandos Úteis De Validação

### Backend

```bash
cd backend/functions
npm run lint
npm run build
```

### Mobile

```bash
cd mobile
flutter analyze
flutter test
```

---

## ☁️ Execução Com Backend Deployado

Se a API estiver publicada no Firebase, o mobile pode ser executado apontando para a URL remota:

```bash
cd mobile
flutter run --dart-define=API_BASE_URL=https://us-central1-mesclainvest-dev.cloudfunctions.net/api
```

Para publicar as functions:

```bash
cd backend
npm --prefix functions run deploy -- --project mesclainvest-dev
```

---

## 📌 Observações Importantes

- A negociação de tokens é totalmente simulada, sem integração com meios de pagamento reais
- O backend foi construído em Node.js + TypeScript, conforme exigido no PDF
- O aplicativo mobile foi construído em Flutter + Dart, conforme exigido no PDF
- O banco utilizado é Firebase Firestore, conforme exigido no PDF
- O acesso ao app depende de autenticação; não há fluxo anônimo
- O 2FA por SMS depende da configuração do Firebase Authentication do projeto

---



