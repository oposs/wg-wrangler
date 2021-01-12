#!/bin/sh
export MOJO_MODE=development
export MOJO_LOG_LEVEL=debug
exec `dirname $0`/wgwrangler.pl prefork --listen 'http://*:7192'
