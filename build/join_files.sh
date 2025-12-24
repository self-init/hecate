#!/bin/bash
outfile="$1"
shift
echo "$outfile"
while [ "$#" -gt 0 ]; do
    echo "-- Start of [$1]" >> "$outfile"
    cat "$1" >> "$outfile"
    echo "-- End of [$1]" >> "$outfile"
    shift # Shift parameters to the left
done
