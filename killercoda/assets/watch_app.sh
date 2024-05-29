#!/usr/bin/env bash

set -euo pipefail

watch "kubectl get pods -n default"
