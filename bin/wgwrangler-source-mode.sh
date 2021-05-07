#!/bin/sh
export MOJO_MODE=development
export MOJO_LOG_LEVEL=debug
export WGwrangler_NO_WG=1
export WGwrangler_CONFIG=t/etc/wgwrangler.yaml
exec $(dirname $0)/wgwrangler prefork --listen 'http://*:7192'
