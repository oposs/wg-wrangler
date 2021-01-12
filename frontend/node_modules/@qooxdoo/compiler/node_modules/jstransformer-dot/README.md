# jstransformer-dot

[doT.js](https://olado.github.io/doT/) support for [JSTransformers](http://github.com/jstransformers).

[![Build Status](https://img.shields.io/travis/jstransformers/jstransformer-dot/master.svg)](https://travis-ci.org/jstransformers/jstransformer-dot)
[![Coverage Status](https://img.shields.io/codecov/c/github/jstransformers/jstransformer-dot/master.svg)](https://codecov.io/gh/jstransformers/jstransformer-dot)
[![Dependency Status](https://img.shields.io/david/jstransformers/jstransformer-dot/master.svg)](http://david-dm.org/jstransformers/jstransformer-dot)
[![Greenkeeper badge](https://badges.greenkeeper.io/jstransformers/jstransformer-dot.svg)](https://greenkeeper.io/)
[![NPM version](https://img.shields.io/npm/v/jstransformer-dot.svg)](https://www.npmjs.org/package/jstransformer-dot)

## Installation

    npm install jstransformer-dot

## API

```js
var dot = require('jstransformer')(require('jstransformer-dot'))

dot.render('Hello, {{=it.name}}!' { name: 'World'}).body
//=> 'Hello, World!'
```

## License

MIT
