'use strict';
const path = require('path');

module.exports = {
	extends: path.join(__dirname, 'index.js'),
	env: {
		node: false,
		browser: true,
    es6: false
	},
  rules: {
    'no-extra-semi': 'off',
    'curly': 'off',
    'no-multi-spaces': 'off', 
    'array-bracket-spacing': 'off', 
    'brace-style': 'off', 
    'camelcase': 'off', 
    'comma-spacing': 'off',
    'indent': 'off', 
    'keyword-spacing': 'off', 
    'linebreak-style': 'off', 
    'max-params': ['warn', { 
			max: 7
		}],
		'no-mixed-spaces-and-tabs': 'off', 
		'no-trailing-spaces': 'off', 
    'object-curly-spacing': 'off', 
    'one-var-declaration-per-line': 'off', 
    'padded-blocks': 'off', 
    'quote-props': 'off', 
    'quotes': 'off', 
    'space-before-blocks': 'off', 
    'space-before-function-paren': 'off', 
    'space-in-parens': 'off', 
    'spaced-comment': 'off'
  }
};
