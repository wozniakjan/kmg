#!/usr/bin/env bash

set -euo pipefail

clear
/scripts/curl_batch.sh
sleep 15
watch --no-title -n 1 --color /scripts/curl_batch.sh
