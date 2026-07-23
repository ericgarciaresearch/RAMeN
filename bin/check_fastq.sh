#!/bin/bash

##########################
### check_fastq_awk.sh ###
##########################

# Usage: ./check_fastq_awk.sh <fastq_directory>

# Check input
if [[ -z "$1" ]]; then
    echo "❌ Usage: $0 <fastq_directory>"
    exit 1
fi

input_dir="$1"
if [[ ! -d "$input_dir" ]]; then
    echo "❌ Directory '$input_dir' does not exist."
    exit 1
fi

cd "$input_dir" || {
    echo "❌ Failed to enter directory '$input_dir'"
    exit 1
}

shopt -s nullglob
files=(*.fastq.gz *.fq.gz)
shopt -u nullglob
if [[ ${#files[@]} -eq 0 ]]; then
    echo "⚠️  No .fastq.gz or .fq.gz files found in '$input_dir'"
    exit 1
fi

outdir="fq_format_check_logs"
mkdir -p "$outdir"

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

######################
# FASTQ FORMAT CHECK #
######################

: > "$outdir/files_good_fastq_format.txt"
: > "$outdir/files_bad_fastq_format.txt"

check_fastq_strict() {
    file="$1"
    base=$(basename "$file")
    log="$outdir/${base}.log"

    zcat "$file" 2>/dev/null | awk '
    {
        line_num++
        if (line_num % 4 == 1 && substr($0,1,1) != "@") {
            print "ERROR: Line " line_num " does not start with @ -> " $0
            bad = 1
        } else if (line_num % 4 == 3 && substr($0,1,1) != "+") {
            print "ERROR: Line " line_num " does not start with + -> " $0
            bad = 1
        } else if (line_num % 4 == 0 && length($0) != seqlen) {
            print "ERROR: Quality line mismatch at line " line_num
            bad = 1
        } else if (line_num % 4 == 2) {
            seqlen = length($0)
        }
    }
    END {
        if (line_num == 0) {
            print "ERROR: File is empty."; exit 1
        } else if (line_num % 4 != 0) {
            print "ERROR: Total lines not divisible by 4 (" line_num " lines)"
            bad = 1
        }
        exit bad
    }' > "$log"

    if [[ $? -eq 0 ]]; then
        echo "$file" >> "$outdir/files_good_fastq_format.txt"
        rm -f "$log"
    else
        echo "$file" >> "$outdir/files_bad_fastq_format.txt"
    fi
}

export -f check_fastq_strict
export outdir
find . -maxdepth 1 -type f \( -name "*.fastq.gz" -o -name "*.fq.gz" \) \
    | parallel --no-notice -j20 check_fastq_strict

good_count=$(wc -l < "$outdir/files_good_fastq_format.txt")
bad_count=$(wc -l < "$outdir/files_bad_fastq_format.txt")
total=$((good_count + bad_count))

echo -e "\n🧪 FASTQ Validation Summary"
echo -e "----------------------------"
echo -e "✅ Passed: ${GREEN}$good_count${NC}"
echo -e "❌ Failed: ${RED}$bad_count${NC}"
echo -e "📊 Total:  ${CYAN}$total${NC}"
if [[ $bad_count -eq 0 ]]; then
    echo -e "${GREEN}🎉 All files passed FASTQ validation.${NC}"
else
    echo -e "${RED}⚠️  Some files failed.${NC}"
    echo -e "See:"
    echo -e "  - $outdir/files_bad_fastq_format.txt"
    echo -e "  - Logs in $outdir/"
fi

##################
# GZIP CHECK
##################

gz_log="$outdir/file.log"
good_gz="$outdir/files_good_gz_format.txt"
bad_gz="$outdir/files_bad_gz_format.txt"
: > "$gz_log" "$good_gz" "$bad_gz"

find . -maxdepth 1 -type f \( -name "*.fastq.gz" -o -name "*.fq.gz" \) | while read -r f; do
    info=$(file "$f")
    echo "$info" >> "$gz_log"
    if echo "$info" | grep -q "gzip compressed data"; then
        echo "$f" >> "$good_gz"
    else
        echo "$f" >> "$bad_gz"
    fi
done

gz_ok=$(wc -l < "$good_gz")
gz_bad=$(wc -l < "$bad_gz")
gz_total=$((gz_ok + gz_bad))

echo -e "\n🧪 GZIP Compression Check"
echo -e "----------------------------"
echo -e "✅ GZIP OK: ${GREEN}$gz_ok${NC}"
echo -e "❌ GZIP Fail: ${RED}$gz_bad${NC}"
echo -e "📦 Total Checked: ${CYAN}$gz_total${NC}"
if [[ $gz_bad -eq 0 ]]; then
    echo -e "${GREEN}🎉 All files are valid GZIP compressed files.${NC}"
else
    echo -e "${RED}⚠️  Some files are not valid GZIP format.${NC}"
    echo -e "See:"
    echo -e "  - $bad_gz"
    echo -e "  - $gz_log"
fi

########################
# PAIRED-END CHECK
########################

pe_log="$outdir/paired_end_check.log"
ok_pe="$outdir/files_good_paired_format.txt"
bad_pe="$outdir/files_bad_paired_format.txt"
: > "$pe_log" "$ok_pe" "$bad_pe"

shopt -s nullglob
files=( *_R1*.fastq.gz *_R1*.fq.gz *.R1*.fastq.gz *.R1*.fq.gz *_r1*.fastq.gz *_r1*.fq.gz *.r1*.fastq.gz *.r1*.fq.gz )
shopt -u nullglob

for r1 in "${files[@]}"; do
    # Cascading replacements to handle all permutations of R1/R2 naming conventions
    r2="${r1/_R1/_R2}"
    r2="${r2/.R1/.R2}"
    r2="${r2/_r1/_r2}"
    r2="${r2/.r1/.r2}"

    [[ -f "$r2" ]] || continue
    
    r1_count=$(zcat "$r1" | awk 'NR%4==1{c++} END{print c}')
    r2_count=$(zcat "$r2" | awk 'NR%4==1{c++} END{print c}')
    
    if [[ -z "$r1_count" || $r1_count -eq 0 || -z "$r2_count" || $r2_count -eq 0 ]]; then
        echo "ERROR: Empty or invalid FASTQ in $r1 or $r2" >> "$pe_log"
        echo "$r1" >> "$bad_pe"
    elif [[ $r1_count -ne $r2_count ]]; then
        echo "ERROR: Mismatched read counts for $r1 ($r1_count) and $r2 ($r2_count)" >> "$pe_log"
        echo "$r1" >> "$bad_pe"
    else
        echo "$r1" >> "$ok_pe"
        # No OK message printed
    fi
done

ok_count=$(wc -l < "$ok_pe")
bad_count=$(wc -l < "$bad_pe")
total=$((ok_count + bad_count))

echo -e "\n🧪 Paired-End FASTQ Validation"
echo -e "------------------------------------------"
echo -e "✅ Pairs OK: ${GREEN}$ok_count${NC}"
echo -e "❌ Pairs Fail: ${RED}$bad_count${NC}"
echo -e "🔢 Total Pairs Checked: ${CYAN}$total${NC}"
if [[ $bad_count -eq 0 ]]; then
    echo -e "${GREEN}🎉 All paired FASTQ files look properly matched and formatted.${NC}"
else
    echo -e "${RED}⚠️  Some paired FASTQ files failed validation. See below:${NC}"
    echo
    grep '^ERROR' "$pe_log"
fi

##########################
# RAW READ COUNT + LENGTH
##########################

read_count_tsv="$outdir/raw_read_count.tsv"
: > "$read_count_tsv"
for f in *.fastq.gz *.fq.gz; do
    [[ -e "$f" ]] || continue
    count=$(zcat "$f" 2>/dev/null | awk 'NR % 4 == 1 {c++} END {if (NR==0) print 0; else print c}')
    [[ -z "$count" ]] && count=0
    echo -e "$f\t$count" >> "$read_count_tsv"
done

echo -e "\n🧪 Generating raw read counts and length analyses"
echo -e "------------------------------------------------------"
echo -e "📄 Read counts written to: ${CYAN}$read_count_tsv${NC}"

awk -F'\t' '
{
  r = $2 + 0
  if (r <= 100) c1++
  else if (r <= 1000) c2++
  else if (r <= 10000) c3++
  else if (r <= 100000) c4++
  else c5++
}
END {
  print "samples\tread_range"
  print c1 "\t0–100"
  print c2 "\t101–1,000"
  print c3 "\t1,001–10,000"
  print c4 "\t10,001–100,000"
  print c5 "\t>100,000"
}' "$read_count_tsv" > "$outdir/raw_read_count_summary.tsv"

##########################
# Read length summary
##########################

length_tsv="$outdir/raw_read_length_summary.tsv"
: > "$length_tsv"

# Header
echo -ne "sample\tave_length" > "$length_tsv"
for ((i=0; i<=400; i+=50)); do
    if (( i < 400 )); then
        echo -ne "\treads_${i}-$((i+49))" >> "$length_tsv"
    else
        echo -e "\treads_400+" >> "$length_tsv"
    fi
done

# Body
for f in *.fastq.gz *.fq.gz; do
    [[ -e "$f" ]] || continue
    zcat "$f" | awk -v sample="$f" '
    NR % 4 == 2 {
        len = length($0)
        total += len
        count++
        bin = (len >= 400) ? 8 : int(len / 50)
        bins[bin]++
    }
    END {
        printf "%s\t%.2f", sample, (count ? total / count : 0)
        for (i = 0; i <= 8; i++) {
            printf "\t%d", bins[i]
        }
        printf "\n"
    }' >> "$length_tsv"
done

echo -e "\n📄 Read length summary written to: ${CYAN}$length_tsv${NC}"

echo -e "\n📄 all output can be found in the subdirectory fq_format_check_logs"
