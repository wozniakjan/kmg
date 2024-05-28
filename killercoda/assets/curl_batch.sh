#!/usr/bin/env bash

set -euo pipefail

NUM_LOOPS=10

ip=$(kubectl get gateway -n envoy-gateway-system -o json eg | jq --raw-output '.status.addresses[0].value')

convert_to_ms() {
    time_str=$1
    min=$(echo $time_str | grep -oP '\d+(?=m)' | sed 's/^0*//')
    sec=$(echo $time_str | grep -oP '\d+.\d+(?=s)' | sed 's/^0*//')
    
    if [ -z "$min" ]; then
        min=0
    fi
    if [ -z "$sec" ]; then
        sec=0
    fi
    
    min_ms=$((min * 60000))
    sec_ms=$(echo "$sec * 1000" | bc)
    
    total_ms=$(echo "$min_ms + $sec_ms" | bc)
    total_ms=$(printf "%.0f" $total_ms)
    echo $total_ms
}

color() {
    elapsed_ms=$1
    if (( $(echo "$elapsed_ms > 100" | bc -l) )); then
        color="\033[0;31m"  # Red for over 1 second
    elif (( $(echo "$elapsed_ms >= 10" | bc -l) )); then
        color="\033[0;33m"  # Orange for over 100 milliseconds
    else
        color="\033[0;32m"  # Green for 100 milliseconds or less
    fi
    echo $color
}

total_time=0
count_1=0
count_2=0
for ((i=1; i<=NUM_LOOPS; i++)); do
    output=$( { time curl -s -H "host: keda-meets-gw.com" http://$ip; } 2>&1 )
    curl_output=$(echo "$output" | head -n -3)
    elapsed_time=$(echo "$output" | grep real | awk '{print $2}')

    elapsed_ms=$(convert_to_ms "$elapsed_time")
    color="$(color $elapsed_ms)"

    printf "%s ${color} %8sms\033[0m\n" "$curl_output" "$elapsed_ms"
    
    total_time=$(echo "$total_time + $elapsed_ms" | bc)
    if [[ "$curl_output" == *"[1]"* ]]; then
        count_1=$((count_1 + 1))
    elif [[ "$curl_output" == *"[2]"* ]]; then
        count_2=$((count_2 + 1))
    fi
done

average_time=$(echo "$total_time / $NUM_LOOPS" | bc)

color="$(color $average_time)"
printf "\nAverage time: ${color}%sms\033[0m\n" "$average_time"
printf "App versions: %s/%s\n" "$count_1" "$count_2"
