#!/usr/bin/env bash
# Dev mode has broken JS MIME types under /cadam — use run-network.sh instead.
exec "$(dirname "$0")/run-network.sh" "$@"
