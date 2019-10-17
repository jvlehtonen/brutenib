#!/bin/bash
#
#SBATCH --mem-per-cpu=960
#
# BruteNiB (Brute Force Negative Image-Based Rescoring)
#

# SHAEP="/app64/shaep/shaep-1.1.2.1036"
SHAEP="/scratch/jlehtone/brutenib/shaep"

[[ $# -lt 2 ]] && exit 1

if [[ -n "${SLURM_ARRAY_TASK_ID}" ]]
then IND=${SLURM_ARRAY_TASK_ID}
elif [[ -n "${3}" ]]
then IND=${3}
else exit 2
fi

GEN=${1}-${IND}
MOF=model-g${GEN}.mol2
MOT=model-g${GEN}-rescore-$(basename ${2} .mol2)
${SHAEP} ${MOF} "${2}" --output-file ${MOT}.txt --noOptimization 1>&2
sed '1d' ${MOT}.txt >> model-g${GEN}-rescore.txt
rm ${MOT}_hits.txt ${MOT}.txt
