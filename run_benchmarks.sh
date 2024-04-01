#!/usr/bin/env bash

# set -e makes the script exit if any command fails
# set -u makes the script exit if any unset variable is used
# set -o pipefail makes the script exit if any command in a pipeline fails
set -euo pipefail

date
#Firefly has 64 physical cores, but 128 logical cores
for i in 1 2 4 8 16 32 64 128
do
    echo "---"
    echo "> timeline, $i threads"
    erl +S $i -noshell -s benchmark test_timeline -s init stop > "benchmarks/result-timeline-$i.txt"
    echo "---"
    echo "> send_message, $i threads"
    erl +S $i -noshell -s benchmark test_send_message -s init stop > "benchmarks/result-send_message-$i.txt"
done
date
