#!/bin/bash

### Cleaning Midori2 fastas and Making taxid_map ###
# Midori2 raw fasta files have sequence names with the entire taxonomic information making these super long. makeblastdb has a limit of 50 characters.
# this script will (1) clean the midori raw fasta file and (2) make the taxid_map, so that a database can be made with makeblastdb

# Cleanning includes:
# (a) Keeping only the accession number, species name (or hybrid), and species' NCBI taxonomic ID (removes extra taxonomic info such as higher taxo-levels as well as lower level such as subpecies, stratins,etc)
	#However, if lower level info did exit for a record (subpecies, strains, etc). You rainbow_bridge will give taxonomic info at this level but higher levels can then be deduce from this by the user
# (b) Truncates names to 50 characters
# This scrip also (c) makes taxid_map. This is require by makeblastdb. Luckily the ncbi taxid of each species is given by midori2 already. This script harvest this info.

# execute with
# bash clean_midori2fasta_for_makeblastdb.sh  <in_dir> <input_fasta> <output_fasta>

# Fasta files
INDIR=$1
input_file=$2
output_file=$3

# Move to INDIR
cd "$INDIR"

# Cleanning fasta
cat "$input_file" | \
	# Truncates first column to the first comma
	awk -F'\t' '{ split($1, a, ","); $1 = a[1]; print }' | \
	# adds a ; at the end of name lines for further processing
	sed '/^>/ s/$/;/'  | \
	# gets rids of white space and everything after species info
	sed -e 's/\(;species_[^;]*_[0-9]*\);.*/\1/'  -e 's/ /_/g' | \
	# keeps only accession number and species info
	awk '/^>/ {split($0, a, ";species_"); split(a[1], b, "."); print b[1] "." b[2] "." a[2]} !/^>/ {print}' | \
	# truncate names to 49 characters
	awk '/^>/ {print substr($0, 1, 47)} !/^>/ {print}' | \
	# add a serial number at the end '-1', '-2', etc to duplicated names.
	awk '/^>/ {count[$0]++; if (count[$0] > 1) $0 = $0 "-" count[$0]-1} 1' > "$output_file"

#### Making taxid_map, which requires:
# column1= seq names (makeblastdb has a 50 characters limit) and 
# column2= ncbi taxonomic ID (this will be taken from the midori2 raw fasta in case there were issues while "cleaning the fasta  in the previous step"

grep '>' "$output_file" | sed 's/>//' > column1
grep '>' "$input_file" | sed 's/.*_//' > column2
paste column1 column2 > taxid_map

# remove temp files
rm column1 column2
