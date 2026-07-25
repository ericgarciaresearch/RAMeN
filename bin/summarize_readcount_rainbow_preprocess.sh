#!/usr/bin/env bash

## Getting raw read counts
cat ../../../data/fq_format_check_logs/raw_read_count.tsv | grep 'R1\.' | sed 's/[_.]R1\.fastq\.gz//' > read_counts_raw_F.tsv
cat ../../../data/fq_format_check_logs/raw_read_count.tsv | grep 'R2\.' | sed 's/[_.]R2\.fastq\.gz//' > read_counts_raw_R.tsv

## Getting preprocess read counts

#!/bin/bash

# Directories to process
dirs=(trim_merge ngsfilter length_filtered relabeled)

for dir in "${dirs[@]}"; do
  out_file="read_counts_${dir}.tsv"
  > "$out_file"

  # Gather all files in desired order
  mapfile -t files < <(ls "$dir"/*.fastq "$dir"/*.fastq.gz "$dir"/*.fasta "$dir"/*.fasta.gz 2>/dev/null)

  tmp_dir=$(mktemp -d)

  # Launch background jobs, saving each result to its own temp file
  for i in "${!files[@]}"; do
    file="${files[$i]}"
    {
      fname=$(basename "$file" | awk -F '_' '{print $1 "_" $2}')
      if [[ "$file" == *.gz ]]; then
        if [[ "$file" == *.fastq.gz ]]; then
          reads=$(zcat "$file" | awk 'END {print NR/4}')
        else
          reads=$(zcat "$file" | grep -c '^>')
        fi
      else
        if [[ "$file" == *.fastq ]]; then
          reads=$(awk 'END {print NR/4}' "$file")
        else
          reads=$(grep -c '^>' "$file")
        fi
      fi
      echo -e "${fname}\t${reads}" > "$tmp_dir/$i.txt"
    } &
  done

  wait

  # Concatenate results in original order
  for i in "${!files[@]}"; do
    cat "$tmp_dir/$i.txt" >> "$out_file"
  done

  rm -r "$tmp_dir"
  echo "✅ Saved: $out_file"
done


## Making combined file

# Validate and merge read count files
echo "🔍 Checking sample consistency across all files..."

# Extract first columns (sample names) from each read count file
cut -f1 read_counts_raw_F.tsv > sample_check_raw_F
cut -f1 read_counts_raw_R.tsv > sample_check_raw_R
cut -f1 read_counts_trim_merge.tsv > sample_check_trim_merge
cut -f1 read_counts_ngsfilter.tsv > sample_check_ngsfilter
cut -f1 read_counts_length_filtered.tsv > sample_check_length_filtered
cut -f1 read_counts_relabeled.tsv > sample_check_relabeled

# Compare them
if ! diff -q sample_check_raw_F sample_check_raw_R >/dev/null || \
   ! diff -q sample_check_raw_F sample_check_trim_merge >/dev/null || \
   ! diff -q sample_check_raw_F sample_check_ngsfilter >/dev/null || \
   ! diff -q sample_check_raw_F sample_check_length_filtered >/dev/null || \
   ! diff -q sample_check_raw_F sample_check_relabeled >/dev/null; then
  echo "❌ Sample mismatch detected across files. Aborting merge."
  rm sample_check_*
  exit 1
fi

echo "✅ Sample names match across all files. Proceeding with merge..."

# Remove temporary sample check files
rm sample_check_*

# Extract value columns (read counts) from all except raw (which keeps sample + counts)
cut -f1,2 read_counts_raw_F.tsv > read_count_F_merged.tmp
cut -f2 read_counts_raw_R.tsv > read_count_R_merged.tmp
cut -f2 read_counts_trim_merge.tsv > col_trim_merge.tmp
cut -f2 read_counts_ngsfilter.tsv > col_ngsfilter.tmp
cut -f2 read_counts_length_filtered.tsv > col_length_filtered.tmp
cut -f2 read_counts_relabeled.tsv > col_relabeled.tmp

# Make header
echo -e "sample\traw_F\traw_R\ttrim_merge\tngsfilter\tl_filtered\trelabeled\t%_loss_trim_merge\t%_loss_ngsfilter\t%_loss_l_filtered\t%_loss_relabeled" > header.tsv

# Combine columns and calculate correct percent losses
paste read_count_F_merged.tmp read_count_R_merged.tmp col_trim_merge.tmp col_ngsfilter.tmp col_length_filtered.tmp col_relabeled.tmp | \
  awk -F"\t" '{
    sample = $1;
    rawF = $2;
    rawR = $3;
    trim = $4;
    ngs = $5;
    lenf = $6;
    relabel = $7;
    avg_raw = (rawF + rawR) / 2;
    loss_trim = (avg_raw > 0) ? (100 - (trim / avg_raw) * 100) : "NA";
    loss_ngs  = (trim > 0)    ? (100 - (ngs / trim) * 100)    : "NA";
    loss_lenf = (ngs > 0)     ? (100 - (lenf / ngs) * 100)    : "NA";
    loss_relabel = (lenf > 0) ? (100 - (relabel / lenf) * 100): "NA";
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%.2f\t%.2f\t%.2f\t%.2f\n", sample, rawF, rawR, trim, ngs, lenf, relabel, loss_trim, loss_ngs, loss_lenf, loss_relabel;
  }' > read_count_preprocessing.tmp

# Add the header
cat header.tsv read_count_preprocessing.tmp > summary-readcount_preprocess.tsv

echo "🎉 Final read count table saved as: summary-readcount_preprocess.tsv"

## Remove intermediate files
rm read_counts_*
rm header.tsv
rm *tmp
