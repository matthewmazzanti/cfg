#!/usr/bin/env bash

nix build -L .#dev
count=1
avg=0
echo $(which time)
TIMEFORMAT='%3E'
while ((count < 40)); do
    sample=$((time ./result/bin/zsh -i -c exit) 2>&1)
#     bc -l <<< "((($count - 1) * $avg) + $sample) / $count"
#     avg=$(bc -l <<< "((($count - 1) * $avg) + $sample) / $count")
#     ((count++))
done
# echo $avg
