import js from '@eslint/js';
import globals from 'globals';

export default [
  // Apply to all JavaScript files
  {
    files: ['**/*.js'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
      globals: {
        ...globals.node,
        ...globals.es2022,
      },
    },
    rules: {
      ...js.configs.recommended.rules,
      'no-console': 'off',
      'no-debugger': 'warn',
      'semi': ['error', 'always'],
      'quotes': ['error', 'single'],
      'comma-dangle': ['error', 'always-multiline'],
      'no-unused-vars': ['error', { 'argsIgnorePattern': '^_' }],
      'no-undef': 'error',
      'eqeqeq': 'error',
      'curly': 'error',
      'brace-style': ['error', '1tbs'],
      'indent': ['error', 2],
      'object-curly-spacing': ['error', 'always'],
      'array-bracket-spacing': ['error', 'never'],
      'comma-spacing': ['error', { 'before': false, 'after': true }],
      'key-spacing': ['error', { 'beforeColon': false, 'afterColon': true }],
      'space-before-blocks': 'error',
      'space-before-function-paren': ['error', 'never'],
      'no-trailing-spaces': 'error',
      'eol-last': 'error',
    },
  },
];
