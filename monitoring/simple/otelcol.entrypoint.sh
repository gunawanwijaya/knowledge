#!/bin/sh
set -e

/otelcol-contrib --config=/config.yml; # > /logpipes/otelcol;
