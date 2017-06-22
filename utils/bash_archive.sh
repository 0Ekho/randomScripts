#!/bin/bash
# gzips your bash history when over 1K lines so you don't loose history
# set bash_history size to >1200 and have this run in a cron (set $HOME)
# stores gzipped logs in same directory as the script
# you can just set your histfile to the date but dislike doing so this mess
log_location=`dirname $0`
line_count=`wc -l < $HOME/.bash_history` 
if (( $line_count > 1000 )); then
    if [ ! -f $log_location/counter.txt ]; then
        echo "1" > "$log_location/counter.txt"
    fi
    log_count=`cat "$log_location/counter.txt"`
    echo $(($log_count+1)) > "$log_location/counter.txt"
    mv "$HOME/.bash_history" "/tmp/bh_e0wrj8gaf4809e_tmp"
    tail -n 100 "/tmp/bh_e0wrj8gaf4809e_tmp" >> "$HOME/.bash_history"
    head -n -100 "/tmp/bh_e0wrj8gaf4809e_tmp" | gzip -c > "$log_location/bash_history.$log_count.gz"
    rm "/tmp/bh_e0wrj8gaf4809e_tmp"
fi
