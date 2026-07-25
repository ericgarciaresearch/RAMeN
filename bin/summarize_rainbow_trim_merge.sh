#!/usr/bin/env bash

set -euo pipefail

############################################
# This script MUST be run from preprocess/
############################################

# This script provides the settings used by AdapterRemoval in trim_merge
#and calculates the average "Trimming Statistics" across files

SETTINGS_GLOB="../work/*/*/*.settings"
OUTFILE="summary-trim_merge.txt"

############################################
# Locate .settings files
############################################

shopt -s nullglob
files=( $SETTINGS_GLOB )
shopt -u nullglob

if [[ ${#files[@]} -eq 0 ]]; then
  echo "ERROR: No .settings files found at $SETTINGS_GLOB" >&2
  exit 1
fi

first="${files[0]}"

############################################
# Generate summary
############################################

{
#####################################
# Print info and invariant sections #
#####################################

echo "This script provides the settings used by AdapterRemoval in trim_merge"
echo "and calculates the average \"Trimming Statistics\" across files"
echo ""

awk '
BEGIN { printing = 1 }

/^\[Trimming statistics\]/ {
  printing = 0
}

printing {
  print
}
' "$first"

############################
# Average trimming stats   #
############################

awk '
/^\[Trimming statistics\]/ {
  instats = 1
  next
}

instats && NF == 0 {
  instats = 0
}

instats {
  split($0, a, ":")
  label = a[1]
  value = a[2]
  sub(/^[[:space:]]+/, "", value)

  sum[label] += value
  count[label]++

  if (!(label in seen)) {
    order[++n] = label
    seen[label] = 1
  }
}

END {
  print "[Trimming statistics]"
  for (i = 1; i <= n; i++) {
    label = order[i]
    avg = sum[label] / count[label]

    if (avg == int(avg))
      printf "Average %s: %d\n", label, avg
    else
      printf "Average %s: %.3f\n", label, avg
  }
}
' "${files[@]}"

} > "$OUTFILE"

echo "Average summary written to: $OUTFILE"

############################################
# Generate read alignment summary
############################################

INPUT="summary-trim_merge.txt"
OUT="summary-readalign_trim_merge.tsv"

awk -F': ' '
BEGIN {
    OFS="\t"
    print "read_type", "number"
}

/Average Total number of read pairs:/ {
    total = $2
}

/Average Number of unaligned read pairs:/ {
    unaligned = $2
}

/Average Number of well aligned read pairs:/ {
    aligned = $2
}

/Average Number of full-length collapsed pairs:/ {
    full = $2
}

/Average Number of truncated collapsed pairs:/ {
    trunc = $2
}

END {
    aligned_not_collapsed = aligned - full - trunc

    print "total", total
    print "unaligned", unaligned
    print "aligned_full-L_collapsed", full
    print "aligned_trunc_collapsed", trunc
    print "aligned_not-collapsed", aligned_not_collapsed
}
' "$INPUT" > "$OUT"

echo "TSV of most relevent reads written to $OUT"

