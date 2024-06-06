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
        if ($1 ~ /blue/) {
            app1++;
            print blue $0 reset;
        } else if ($1 ~ /prpl/) {
            app2++;
            print magenta $0 reset;
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

function metrics_from_interceptor() {
    kubectl get --raw '/api/v1/namespaces/keda/services/keda-add-ons-http-interceptor-admin:9090/proxy/queue' | \
        jq 'to_entries | map({key, value: ((.value.RPS | tostring) + " RPS")}) | from_entries'
}
export -f metrics_from_interceptor

watch --no-title -n 1 --color -x bash -c "colorize_pods; echo ''; metrics_from_interceptor"
