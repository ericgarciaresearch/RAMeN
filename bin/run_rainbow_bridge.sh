#!/bin/bash
#SBATCH --job-name=ramen	       # Job name
#SBATCH --partition=main               # Partition name (prob a good idea to stick to medium memmory nodes (medmem)
#SBATCH --mem=180G                     # Total memory per node (adjust as needed)(96G for standard, 185G for medmem, and 1.5T for himem)
#SBATCH --nodes=1                      # Number of nodes
#SBATCH -c 20  			       # Number of CPU cores per task
#SBATCH --time=00:00:00                # Time limit (D-HH:MM:SS)
#SBATCH --output=ramen-%j.out	       # Standard output and error log (%j will be replaced by job ID)
#SBATCH --mail-type=END,FAIL           # Send email on all job events
#SBATCH --mail-user=<email>	       # Send all emails to email_address

#####################################
###  RAMeN - Metabarcoding Module ###
### 	  run_rainbow_bride       ###
#####################################

# MAKE A COPY of this script in your run dir
# You will need a reference database and a barcode decode file 
#if the primers have not been stripped from reads.
# This script run rainbow_bridge locally
# All parameters are specified as flags in command below. Modify as needed.

#----------------------------
# Execute:
# cp RAMeN/bin/run_rainbow_bridge.sh <runDIR>
# <modify flags in the script as needed>
# cd <runDIR>
# sbatch run_rainbow_bridge.sh
#----------------------------

# NOTES on databases:
# Many databases such as NCBI and MIDORI2 are regularly updated
# Make sure you have the latest version of your preferred database
# When specifying a database, use the path and the basename without extensions
# ("/path/nt" for NCBI's nucleotide database for example)

# Load and activate necessary modules and software (modify according to your system)
source ~/.bashrc
module load bio/rainbow_bridge/202603 2>/dev/null
mamba activate rainbow_bridge

# Print SLURM configuration
#env | grep SLURM

# Record the start time
start_time=$(date +%s)
echo "Start time: $(date)"
echo ""

# Get the name and full path of the script executed
script_command=$(scontrol show job $SLURM_JOB_ID | awk -F= '/Command=/{print $2}' | awk '{print $1}')

## Initial reporting. Print parameters used
# Write the script name to the output file
echo "The script executed is: $script_command"
echo "Script executed from: $(pwd)"
echo ""
if [[ -n "$PARAMSFILE" ]]; then
	echo -e "Using params file=$PARAMSFILE\n"
	echo "cat $PARAMSFILE"
	cat $PARAMSFILE
	echo ""
else
	echo -e "Using flags in script rather than a params file"
	echo "Command used:"
	cat $script_command | grep '^next' | sed 's/\\//'
	cat $script_command | grep '^  --' | sed -e 's/  --//g' -e 's/\\//'
	echo ""
fi

#nextflow run mhoban/rainbow_bridge \
nextflow run /path_to_rainbow_bridge/rainbow_bridge.nf \
  --maxMemory '90 GB' \
  --paired \
  --demultiplexed-by index \
  --reads ../../data/ \
  --barcode ../../data/demuxed_barcodes.tsv \
  --blast \
  --blast-db 'path_to_database/basename' \
  --publish-mode symlink \
  --alpha 2 \
  --zotu-identity 1 \
  --max-query-results 1000 \
  --primer-mismatch 2 \
  --qcov 90 \
  --percent-identity 90 \
  --evalue 0.001 \
  --lulu \
  --fastqc \
  --collapse-taxonomy \
  --dropped "LCA_dropped" \
  --lca-qcov 90 \
  --lca-pid 90 \
  --lca-diff 1 \
  --taxdump /path/new_taxdump.zip

# Record the end time
end_time=$(date +%s)
echo ""
echo "End time: $(date)"

# Calculate the elapsed time
elapsed_time=$((end_time - start_time))

# Convert elapsed time to hours, minutes, and seconds
hours=$((elapsed_time / 3600))
minutes=$(( (elapsed_time % 3600) / 60 ))
seconds=$((elapsed_time % 60))

echo -e "Total time taken: ${hours}h ${minutes}m ${seconds}s\n"

