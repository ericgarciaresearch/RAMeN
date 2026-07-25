#!/usr/bin/env bash

set -uo pipefail

############################################

# Ensure job runs from directory submitted

############################################

cd "$SLURM_SUBMIT_DIR"

# Record the start time

start_time=$(date +%s)

# Get the name and full path of the script executed

script_command=$(scontrol show job "$SLURM_JOB_ID" | awk -F= '/Command=/{print $2}' | awk '{print $1}')

echo "=========================================="
echo "Preprocess Summary Job"
echo "Job ID: $SLURM_JOB_ID"
echo "Started: $(date)"
echo "The script executed is: $script_command"
echo "Running from: $(pwd)"
echo "=========================================="
echo

############################################

# Script locations (relative to preprocess/)

############################################

SCRIPT_DIR="../../../scripts"

SCRIPT1="$SCRIPT_DIR/summarize_rainbow_trim_merge.sh"
SCRIPT2="$SCRIPT_DIR/summarize_readcount_rainbow_preprocess.sh"
SCRIPT3="$SCRIPT_DIR/summarize_readL_rainbow_preprocess.sh"

echo "This script runs the following 3 sub-scripts:"
echo "summarize_rainbow_trim_merge.sh: average trimming stats from trim_merge (AdapterRemoval)"
echo "summarize_readcount_rainbow_preprocess.sh: average read counts and read loss at each preprocessing step"
echo "summarize_readL_rainbow_preprocess.sh: average read length after each preprocessing step"
echo
echo "=============="

############################################

# Function to run scripts without aborting

############################################

any_failed=0
failed_scripts=()

run_script() {
local script="$1"
local name="$2"

```
echo "Running $name"

if bash "$script"; then
    echo "SUCCESS: $name"
else
    status=$?
    echo "FAILED: $name (exit code $status)"
    any_failed=1
    failed_scripts+=("$name")
fi

echo
echo "=============="
```

}

############################################

# Run scripts

############################################

run_script "$SCRIPT1" "summarize_rainbow_trim_merge.sh"
run_script "$SCRIPT2" "summarize_readcount_rainbow_preprocess.sh"
run_script "$SCRIPT3" "summarize_readL_rainbow_preprocess.sh"

############################################

# Summary

############################################

echo
echo "=========================================="
echo "SUMMARY"
echo "=========================================="

if [ "$any_failed" -eq 0 ]; then
echo "All preprocess summaries completed successfully."
else
echo "The following script(s) failed:"
printf '  - %s\n' "${failed_scripts[@]}"
fi

############################################

# Timing information

############################################

end_time=$(date +%s)

echo
echo "End time: $(date)"

elapsed_time=$((end_time - start_time))

hours=$((elapsed_time / 3600))
minutes=$(((elapsed_time % 3600) / 60))
seconds=$((elapsed_time % 60))

echo "Total time taken: ${hours}h ${minutes}m ${seconds}s"
echo

############################################

# Exit status

############################################

if [ "$any_failed" -ne 0 ]; then
exit 1
fi

exit 0

