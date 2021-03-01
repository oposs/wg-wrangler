#!/bin/sh
export MOJO_MODE=development
export MOJO_LOG_LEVEL=debug
export IS_TESTING=1
export WIREGUARD_HOME=../dummy_wg_home/
exec $(dirname $0)/wgwrangler.pl prefork --listen 'http://*:7192'
