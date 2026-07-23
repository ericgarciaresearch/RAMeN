#!/bin/bash

# This script renames fastq files from Jonah Ventures sequencing facility.
# JV190_16SDegenerate_WhitneyJonathan_S045173.1.R1.fastq.gz  ->  S045173_1.R1.fastq.gz

### To execute mMove to dir where files are and:
# first do a dry run
# bash rename_fastqs.sh --dry-run

#if renaming looks good, then
# bash rename_fastqs.sh --rename

#### Script ####

# Check if mode is provided
if [[ "$1" != "--dry-run" && "$1" != "--rename" ]]; then
    echo "Usage: $0 [--dry-run | --rename]"
    exit 1
fi

for f in *_S0*.fastq.gz; do
    new_name=$(echo "$f" | sed -e 's/.*_S0/S0/' -e 's/\./_/')
    if [[ "$1" == "--dry-run" ]]; then
        echo "[DRY RUN] $f  ->  $new_name"
    else
        echo "Renaming: $f  ->  $new_name"
        mv "$f" "$new_name"
    fi
done

