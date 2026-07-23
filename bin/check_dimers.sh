#!/bin/bash

# ==========================================
# Configuration
# ==========================================
report_file="primer_dimer_report.tsv"
avg_file="average_primer_dimer.tsv"
SEQAdapter=$1

# ==========================================
# 1. Generate the Individual Report
# ==========================================
# Write header to output file
echo -e "Sample\tTotal_Reads\tDimer_Reads\t%_Dimers" > "$report_file"

if [[ -z "${SEQAdapter:-}" ]]; then
  echo "ERROR: No adapter sequence provided"
  echo "Usage: $0 <ADAPTER_SEQUENCE>"
  exit 1
fi

echo "Script will search for the adapter ${SEQAdapter}"
echo "Processing files... (This may take a moment)"

# Loop through all R1 fastq.gz files
for file in *.R1.fastq.gz; do
    
    # Calculate stats using awk
    # We look for the sequencer adapter "given as an argument by user" appearing within the first 100 bases
    stats=$(zcat "$file" | awk -v adapter="$SEQAdapter" '
        BEGIN { total=0; dimers=0 }
        NR%4==2 { 
            total++; 
            pos = index($0, adapter);
            if (pos > 0 && pos < 100) {
                dimers++;
            }
        } 
        END { 
            if (total > 0) 
                printf "%d\t%d\t%.2f", total, dimers, (dimers/total)*100;
            else 
                printf "0\t0\t0.00";
        }
    ')

    # Save to the main report file
    echo -e "${file}\t${stats}" >> "$report_file"
    
    # Optional: Print progress to screen (overwrites line to reduce clutter)
    echo -ne "Processed: $file\r"
done

echo -e "\n✅ Individual file analysis complete. Saved to: $report_file"

# ==========================================
# 2. Calculate Averages for Separate File
# ==========================================
# This reads the report file we just made, skips the header (NR>1), 
# sums the columns, and divides by the number of files (count).

awk 'NR>1 {
    sum_total += $2;
    sum_dimers += $3;
    sum_percent += $4;
    count++;
} 
END {
    if (count > 0) {
        print "Avg_Total_Reads\tAvg_Dimer_Reads\tAvg_%_Dimers";
        printf "%.0f\t%.0f\t%.2f\n", sum_total/count, sum_dimers/count, sum_percent/count;
    } else {
        print "No data found to average.";
    }
}' "$report_file" > "$avg_file"

echo "📊 Global averages calculated. Saved to: $avg_file"
