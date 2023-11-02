// prettier.config.js, .prettierrc.js, prettier.config.cjs, or .prettierrc.cjs

/** @type {import("prettier").Config} */
const config = {
  trailingComma: "none",
  tabWidth: 4,
  singleQuote: true,
  arrowParens: "avoid",
  plugins: [require.resolve('prettier-plugin-apex')],
  overrides: [{
      files: "**/lwc/**/*.html",
      options: { parser: "lwc" }
  }, {
      files: "*.{cmp,page,component}",
      options: { parser: "html" }
  }, {
      files: "*.{md}",
      options: { parser: "markdown" }
  }]
};

module.exports = config;