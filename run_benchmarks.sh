#!/usr/bin/env bash

# set -e makes the script exit if any command fails
# set -u makes the script exit if any unset variable is used
# set -o pipefail makes the script exit if any command in a pipeline fails
set -euo pipefail



#test_timeline/0, test_send_message/0, test_profile/0, test_send_message_latency_broadcasting/0, test_send_message_latency_broadcasting_noFollower/0, test_timeline_subs/0, test_timeline_seq/0]).


date
#Firefly has 64 physical cores, but 128 logical cores
echo "---"
echo "> test_timeline_seq, 1 threads"
erl +S 1 -noshell -s benchmark test_timeline_seq -s init stop > "benchmarks/seq/result-timeline.txt"
echo "---"
echo "> test_profile_seq, 1 threads"
erl +S 1 -noshell -s benchmark test_profile_seq -s init stop > "benchmarks/seq/result-profile.txt"
echo "---"
echo "> test_send_message_seq, 1 threads"
erl +S 1 -noshell -s benchmark test_send_message_seq -s init stop > "benchmarks/seq/result-message.txt"

for i in 1 2 4 8 16 32 64 128
do
    echo "---"
    echo "> timeline_thresholds, $i threads"
    erl +S $i -noshell -s benchmark test_timeline_thresholds -s init stop > "benchmarks/timeline/result-timeline_T-$i.txt"
    
    echo "---"
    echo "> timeline, $i threads"
    erl +S $i -noshell -s benchmark test_timeline -s init stop > "benchmarks/timeline/result-timeline-$i.txt"
    echo "---"
    echo "> send_message, $i threads"
    erl +S $i -noshell -s benchmark test_send_message -s init stop > "benchmarks/messages/result-send_message-$i.txt"
    echo "---"
    echo "> get_profile, $i threads"
    erl +S $i -noshell -s benchmark test_profile -s init stop > "benchmarks/profile/result-get_profile-$i.txt"
    echo "---"
    echo "> get_profile_ones, $i threads"
    erl +S $i -noshell -s benchmark test_profile_1 -s init stop > "benchmarks/profile/result-get_profile_ones-$i.txt"

    echo "---"
    echo "> test_send_message_latency_broadcasting, $i threads"
    erl +S $i -noshell -s benchmark test_send_message_latency_broadcasting -s init stop > "benchmarks/latency/result-message_latency-$i.txt"
    echo "---"
    echo "> test_send_message_latency_broadcasting, $i threads"
    erl +S $i -noshell -s benchmark test_send_message_latency_broadcasting_10 -s init stop > "benchmarks/latency/result-message_latency_10follower-$i.txt"

    echo "---"
    echo "> test_send_message_latency_broadcasting_noFollower, $i threads"
    erl +S $i -noshell -s benchmark test_send_message_latency_broadcasting_noFollower -s init stop > "benchmarks/latency/result-message_latency_noFollower-$i.txt"
    echo "---"
    echo "> test_timeline_subs, $i threads"
    erl +S $i -noshell -s benchmark test_timeline_subs -s init stop > "benchmarks/subs/result-timeline-$i.txt"

    echo "--------- $i Threads done with time ----------- " 
    date 
    echo "------------------------------------------------"

done
date
