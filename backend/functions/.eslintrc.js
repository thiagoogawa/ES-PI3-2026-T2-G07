/**
 * Thiago Ryuji Ogawa - RA:24024450
 *
 * Configuracao de lint do backend em Cloud Functions.
 * Define regras de estilo e consistencia para manter o codigo
 * TypeScript previsivel durante desenvolvimento e revisao.
 */

module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    "google",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["tsconfig.json", "tsconfig.dev.json"],
    sourceType: "module",
    tsconfigRootDir: __dirname,
  },
  ignorePatterns: [
    "/lib/**/*", // Ignore built files.
    "/generated/**/*", // Ignore generated files.
  ],
  plugins: [
    "@typescript-eslint",
    "import",
  ],
  rules: {
    "quotes": ["error", "double"],
    "import/no-unresolved": 0,
    "indent": ["error", 2],
    "new-cap": [
      "error",
      { "properties": false, "capIsNewExceptions": ["Router"] },
    ],
    "@typescript-eslint/no-unused-vars": [
      "warn",
      { "argsIgnorePattern": "^_" },
    ],
    "require-jsdoc": 0,
    "valid-jsdoc": 0,
  },
  overrides: [
    {
      files: [".eslintrc.js"],
      rules: {
        "object-curly-spacing": 0,
      },
    },
  ],
};
