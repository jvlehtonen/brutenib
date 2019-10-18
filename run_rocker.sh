#!/bin/bash
shopt -s extglob
#
# Brute helper script
#

ROCKER="rocker"
OPT="-an LIG -c 2 -lp -las 20 -ts 18 -nro"

[[ $# -lt 1 ]] && exit 1

if [[ -n "${2}" ]]
then
    if [[ "${2}x" = "BRx" ]]
    then
	BRA=20
    else
	BRA=${2#BR}
    fi
fi

# Reduce Shaep output to two columns
MOT=$1
awk -f ../trim-shaep.awk ${MOT}.txt > ${MOT}-trim.txt
#
MOR=${MOT}_enrich.txt
${ROCKER} ${MOT}-trim.txt ${OPT} -EFd 1 | grep -v Loaded > ${MOR}
${ROCKER} ${MOT}-trim.txt ${OPT} -BR ${BRA} -EFd 5 | tail -2 >> ${MOR}
# echo ${ROCKER} ${MOT}-trim.txt ${OPT} -BR ${BRA} -EFd 5 | tail -2
