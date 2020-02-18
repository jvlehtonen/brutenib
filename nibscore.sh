#!/bin/bash
#
#SBATCH --mem-per-cpu=960
#
# BruteNiB (Brute Force Negative Image-Based Rescoring)
#

SHAEP="${SHAEP:=shaep}"
[[ $# -lt 3 ]] && exit 1

MOF=${1}
BASE=${MOF%.mol2}
GEN=${BASE#model-g}
MOT=${BASE}-rescore-$(basename ${2} .mol2)
echo "#${SHAEP} ${MOF} "${2}" --output-file ${MOT}.txt --espweight ${3} ${4:+--exclusion ${4}} --noOptimization#"
${SHAEP} ${MOF} "${2}" --output-file ${MOT}.txt --espweight ${3} ${4:+--exclusion ${4}} --noOptimization 1>&2
sed '1d' ${MOT}.txt >> ${BASE}-rescore.txt
rm ${MOT}_hits.txt ${MOT}.txt
