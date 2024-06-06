#!/usr/bin/env bash

set -euo pipefail

function colorize_pods() {
    kubectl get pods -n default | awk '
    BEGIN {
        app1=0;
        app2=0;
        magenta="\033[1;35m";
        blue="\033[1;34m";
        reset="\033[0m";
    }
    NR==1 {
        print $0;
    }
    NR>1 {
        if ($1 ~ /app-1/) {
            app1++;
            print magenta $0 reset;
        } else if ($1 ~ /app-2/) {
            app2++;
            print blue $0 reset;
        } else {
            print $0;
        }
    }
    END {
        print "\napp revisions: " magenta app1 reset " / " blue app2 reset; 
    }
    '
}
export -f colorize_pods

watch --no-title -n 1 --color -x bash -c "colorize_pods; echo ''; kubectl get --raw '/api/v1/namespaces/keda/services/keda-add-ons-http-interceptor-admin:9090/proxy/queue' | jq '.'"
