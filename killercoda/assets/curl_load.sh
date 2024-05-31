#!/usr/bin/env bash

set -euo pipefail

clear
/scripts/curl_batch.sh
echo "\n\nPress enter to continue..."
read x
watch --no-title -n 1 --color /scripts/curl_batch.sh
