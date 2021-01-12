"use strict";

module.exports = {
	env: {
		es6: true,
		node: true
	},
	globals: {
		"q": false,
		"qx": false,
		"qxWeb": false
	},
	parserOptions: {
		ecmaFeatures: {
			jsx: true
		},
		sourceType: "module"
	},
	plugins: [
		"@qooxdoo/qx",
		"jsdoc"
	],
	rules: {

		// Special qooxdoo stuff
		// to slow
		"@qooxdoo/qx/no-illegal-private-usage": "off",
		"@qooxdoo/qx/no-refs-in-members": "error",

		/*
     * "array-bracket-spacing": ["error", "never"],
     *
     * Super-strict on spacing in arrays literals. Does not fit in many use
     * cases and difficult to control because different editors routinely handle
     * this differently. Very subjective and has little effect on readbility
     *
     *
     */

		/*
     * "object-curly-spacing": ["error", "never"],
     *
     * Super-strict on spacing in object literals. Does not fit in many use
     * cases and difficult to control because different editors routinely handle
     * this differently. Very subjective and has little effect on readbility
     */

		/*
     * "object-property-newline": "error",
     *
     * Super-strict on spacing in object literals. Does not fit in many use
     * cases. Very subjective and often has little effect on readbility
     */

		/*
     * "space-before-function-paren": ["error", {
     *      anonymous: "never",
     *      named: "never"
     * }],
     *
     * Super strict about placing of spaces before parentheses. Very subjective
     * and has little effect on readbility
     */

		/*
     *   "spaced-comment": ["error", "always", {
     *       block: {
     *           balanced: true,
     *           markers: ["!"]
     *       },
     *       line: {
     *           exceptions: ["-"]
     *       }
     *   }],
     *
     * Forces a space before the closing of a comment.  Very subjective
     * and has little effect on readbility, no benefit.
     */

		/*
     * Questionable, especially for simple statements, but `curly` allows backwards
     * compatibility with the generator
     */
		"curly": "error",

		/*
     * "indent": ["error", 2, { SwitchCase: 1 }],
     *
     * Enforces a very specific level of indenting, which can be difficult to control
     * between editors.
     *
     */

		/*
     * "no-trailing-spaces": "error"
     *
     * Difficult to control because different editors routinely handle this
     * differently, auto indent will create spaces. Has little effect on
     * readbility
     */

		/*
     * "no-nested-ternary": "warn",
     *
     * Rejects really common code, EG sort routines often use `return a < b ? -1 :
     * a > b ? 1 : 0`
     */

		/*
     * 'no-negated-condition': 'error',
     *
     * Rejects `if (!expr) {} else {}` in favour of `if (expr) {} else {}`.  Does not
     * necessarily improve readability and provides no code safety.
     */

		/*
     * 'no-shadow': 'error',
     *
     * Prevents very common use cases such as nested functions with callbacks
     * from using the same parameter name, eg `cb`.  This causes the user to
     * make meaningless name changes and makes it harder to refactor code.
     */

		/*
     * "no-new-func": "error",
     *
     * Prevents using `new Function("...code...")` which is the whole purpose of
     * using `new Function()`!
     */

		/*
     * 'no-use-before-define': ['error', 'nofunc'],
     *
     * Debatable, but prevents hoisting which is a valuable and valid tavascrfipt tool
     */

		/*
     * "no-confusing-arrow": "error",
     *
     * data => (data === "false" ? "" : data) looks much nicer than
     * data => {
     *   return (data === "false" ? "" : data)
     * }
     */

		"accessor-pairs": "error",
		"array-bracket-newline": "off",

		"array-callback-return": "error",
		"array-element-newline": "off",
		"arrow-body-style": "error",
		"arrow-parens": ["error", "as-needed"],
		"arrow-spacing": ["error", {
			after: true, before: true
		}],
		"block-scoped-var": "off",
		"block-spacing": "error",
		"brace-style": ["error", "1tbs", {
			allowSingleLine: false
		}], // disabled because of https://github.com/eslint/eslint/issues/3420
		"callback-return": "off",

		"camelcase": "off",
		"capitalized-comments": "off",
		"class-methods-use-this": "error",

		"comma-dangle": ["error", "never"],
		"comma-spacing": ["error", {
			after: true, before: false
		}],
		"comma-style": ["error", "last"],
		"complexity": "off",
		"computed-property-spacing": ["error", "never"],
		"constructor-super": "error",
		"consistent-return": "error",
		"consistent-this": "off",

		"default-case": "off",
		"dot-location": ["error", "property"],
		"dot-notation": 0,
		"eol-last": "error",
		"eqeqeq": 0,
		"for-direction": "error",
		"func-call-spacing": ["error", "never"],
		"func-names": "off",
		"func-style": "off",
		"generator-star-spacing": ["error", "both"],
		"guard-for-in": "off",
		"handle-callback-err": "warn",
		"id-blacklist": "error", // missing blacklist
		"id-length": "off",
		"id-match": "off",

		"init-declarations": "off",
		"jsx-quotes": "error",
		"key-spacing": 0,
		"keyword-spacing": "error",
		"line-comment-position": "off",
		"linebreak-style": ["error", "unix"],
		"lines-around-comment": "off",
		"lines-around-directive": "off",
		"max-depth": "off",
		"max-len": "off",
		"max-lines": "off",
		"max-nested-callbacks": "error",
		"max-params": "off",
		"max-statements": "off",
		"max-statements-per-line": "error",
		"multiline-ternary": "off",
		"new-cap": ["error", {
			capIsNew: true, newIsCap: true
		}],
		"new-parens": "error", /*
	 * "newline-per-chained-call": "error",
	 * Does not make sense as a general rule, decreases readability for short chained calls
	 */
		"no-alert": "error",
		"no-array-constructor": "error",
		"no-caller": "error",
		"no-case-declarations": "error",
		"no-class-assign": "error",
		"no-cond-assign": "error",
		"no-console": "off",
		"no-continue": "off",
		"no-const-assign": "error",
		"no-constant-condition": "error",
		"no-control-regex": "error",
		"no-debugger": "error",
		"no-delete-var": "error",
		"no-div-regex": "error",
		"no-dupe-args": "error",
		"no-dupe-class-members": "error",
		"no-dupe-keys": "error",
		"no-duplicate-case": "error",
		"no-duplicate-imports": ["error", {
			includeExports: true
		}],
		"no-else-return": "error",
		"no-empty": ["error", {
			allowEmptyCatch: true
		}],
		"no-empty-function": "off",

		"no-empty-character-class": "error",
		"no-empty-pattern": "error",
		"no-eq-null": "error",
		"no-eval": "error",
		"no-ex-assign": "error",
		"no-extend-native": "error",
		"no-extra-bind": "error",
		"no-extra-boolean-cast": "error",
		"no-extra-label": "error", // disabled because of https://github.com/eslint/eslint/issues/6028
		// "no-extra-parens": [2, "all", {nestedBinaryExpressions: false}],
		"no-extra-semi": "error",
		"no-fallthrough": "error",
		"no-floating-decimal": "error",
		"no-func-assign": "error",
		"no-global-assign": "error",
		"no-implicit-coercion": "error",
		"no-implicit-globals": "error",
		"no-implied-eval": "error",
		"no-inline-comments": "off", // disabled because qooxdoo allows this in listener
		"no-invalid-this": "off",
		"no-inner-declarations": "error",
		"no-invalid-regexp": "error",
		"no-irregular-whitespace": "error",
		"no-iterator": "error",
		"no-label-var": "error",
		"no-labels": "error",
		"no-lone-blocks": "error",
		"no-lonely-if": "error",
		"no-loop-func": 0,
		"no-magic-numbers": "off",
		"no-mixed-operators": "off",
		"no-mixed-requires": ["error", {
			allowCall: true, grouping: true
		}],
		"no-mixed-spaces-and-tabs": "error",
		"no-multi-spaces": "error",
		"no-multi-str": "off",
		"no-multiple-empty-lines": ["off", {
			max: 1
		}],

		"no-new": "error",
		"no-new-object": "error",
		"no-new-require": "error",
		"no-new-symbol": "error",
		"no-new-wrappers": "error",
		"no-obj-calls": "error",
		"no-octal": "error",
		"no-octal-escape": "error",
		"no-path-concat": "error",
		"no-proto": "error",
		"no-prototype-builtins": "error",
		"no-redeclare": "error",
		"no-regex-spaces": "error",
		"no-restricted-globals": "error",
		"no-restricted-imports": "error",
		"no-restricted-modules": "error",
		"no-restricted-properties": "error",
		"no-restricted-syntax": ["error", "WithStatement"],
		"no-return-assign": "off",
		"no-script-url": "error",
		"no-self-assign": ["error", {
			props: true
		}],
		"no-self-compare": "error",
		"no-sequences": "error",
		"no-shadow-restricted-names": "error",
		"no-sparse-arrays": "error",
		"no-template-curly-in-string": "error",
		"no-this-before-super": "error",
		"no-throw-literal": "error",
		"no-undef": ["error", {
			typeof: true
		}],
		"no-undef-init": "error",
		"no-unexpected-multiline": "error",
		"no-unmodified-loop-condition": "error",
		"no-unneeded-ternary": "error",
		"no-unreachable": "error",
		"no-unsafe-finally": "error",
		"no-unsafe-negation": "error",
		"no-unused-expressions": 0,
		"no-unused-labels": "error",
		"no-unused-vars": ["error", {
			"vars": "all", "args": "none", "caughtErrors": "none"
		}],
		"no-useless-call": "error",
		"no-useless-computed-key": "error",
		"no-useless-concat": "error",
		"no-useless-constructor": "error",
		"no-useless-escape": "off",
		"no-useless-rename": "error",
		"no-void": "error",
		"no-warning-comments": "warn",
		"no-whitespace-before-property": "error",
		"no-with": "error",

		"one-var": ["error", "never"],
		"one-var-declaration-per-line": "error",
		"operator-assignment": ["error", "always"],
		"operator-linebreak": ["error", "after"],

		"padded-blocks": ["error", "never"], // of because generaty.py do not allow missing quote for events
		// "quote-props": ["error", "consistent-as-needed"],
		"quote-props": "off",
		"quotes": ["error", "double", {
			allowTemplateLiterals: true
		}],
		"radix": "off",
		"require-yield": "error",
		"rest-spread-spacing": ["error", "never"],
		"semi": ["error", "always"],
		"semi-spacing": ["error", {
			after: true, before: false
		}],
		"space-before-blocks": ["error", "always"],
		"space-in-parens": ["error", "never"],
		"space-infix-ops": 0,
		"space-unary-ops": "error",
		"strict": "off",
		"switch-colon-spacing": "error",
		"symbol-description": "error",
		"template-curly-spacing": "error",
		"template-tag-spacing": "error",

		"unicode-bom": ["error", "never"],
		"use-isnan": "error",
		"valid-jsdoc": "off",
		"valid-typeof": ["error", {
			requireStringLiterals: true
		}],
		"vars-on-top": "off",

		"wrap-iife": ["error", "inside"],
		"wrap-regex": "off",

		"yield-star-spacing": ["error", "both"],
		"yoda": "error",

		// JSDoc rules
		"jsdoc/check-tag-names": "off", // for this to work, the preferred tags have to be configured
		"jsdoc/check-param-names": "warn",
		"jsdoc/check-types": "off", // for example, "Boolean -> boolean"
		"jsdoc/require-jsdoc": "warn",
		"jsdoc/require-param": "warn",
		"jsdoc/require-param-description": "off",
		"jsdoc/require-param-name": "warn",
		"jsdoc/require-param-type": "off",
		"jsdoc/require-returns-type": "warn",
		"jsdoc/valid-types": "warn"
	}
};
