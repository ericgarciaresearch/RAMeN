#!/usr/bin/env bash

set -euo pipefail

OUT="summary-readL_preprocess.tsv"
RAW_TSV="../../../data/fq_format_check_logs/raw_read_length_summary.tsv"

echo -e "step\tlength" > "$OUT"

#################################
# RAW (use ave_length, not bins)
#################################
if [[ -f "$RAW_TSV" ]]; then
    awk -F'\t' '
        NR == 1 { next }
        {
            ave = $2
            total = 0
            for (i = 3; i <= NF; i++) total += $i

            for (j = 1; j <= total; j++) {
                print "raw\t" ave
            }
        }
    ' "$RAW_TSV" >> "$OUT"
else
    echo "$RAW_TSV doesn't exist — skipping raw" >&2
fi

#################################
# FASTQ steps
#################################
for step in trim_merge ngsfilter length_filtered; do
    [[ -d "$step" ]] || continue

    for fq in "$step"/*.fastq; do
        [[ -f "$fq" ]] || continue

        awk -v step="$step" '
            NR % 4 == 2 {
                print step "\t" length($0)
            }
        ' "$fq" >> "$OUT"
    done
done

#################################
# FASTA steps (multi-line aware)
#################################
for step in relabeled merged; do
    [[ -d "$step" ]] || continue

    for fa in "$step"/*.fasta; do
        [[ -f "$fa" ]] || continue

        awk -v step="$step" '
            /^>/ {
                if (seqlen > 0) {
                    print step "\t" seqlen
                }
                seqlen = 0
                next
            }
            {
                seqlen += length($0)
            }
            END {
                if (seqlen > 0) {
                    print step "\t" seqlen
                }
            }
        ' "$fa" >> "$OUT"
    done
done

echo "Wrote $OUT"
echo
