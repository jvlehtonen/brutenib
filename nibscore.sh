#!/bin/bash
#
#SBATCH --mem-per-cpu=960
#
# BruteNiB (Brute Force Negative Image-Based Rescoring)
#

# SHAEP="/app64/shaep/shaep-1.1.2.1036"
SHAEP="/scratch/jlehtone/brutenib/shaep"

[[ $# -lt 3 ]] && exit 1

MOF=${1}
BASE=${MOF%.mol2}
GEN=${BASE#model-g}
MOT=${BASE}-rescore-$(basename ${2} .mol2)
${SHAEP} ${MOF} "${2}" --output-file ${MOT}.txt --espweight ${3} --noOptimization 1>&2
sed '1d' ${MOT}.txt >> ${BASE}-rescore.txt
rm ${MOT}_hits.txt ${MOT}.txt
