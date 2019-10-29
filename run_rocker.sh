#!/bin/bash
shopt -s extglob
#
# Brute helper script
#

ROCKER="rocker"
OPT="-an ${ACTIVE:-LIG} -c 2 -lp -las 20 -ts 18 -nro"

[[ $# -lt 1 ]] && exit 1

case "${2}" in
    'BR') BRA=20 ;;
    BR*)  BRA=${2#BR} ;;
    *)    ;;
esac

# Reduce Shaep output to two columns
MOT=$1
awk -f ../trim-shaep.awk ${MOT}.txt > ${MOT}-trim.txt
#
MOR=${MOT}_enrich.txt
${ROCKER} ${MOT}-trim.txt ${OPT} -EFd 1 | grep -v Loaded > ${MOR}
${ROCKER} ${MOT}-trim.txt ${OPT} -BR ${BRA} -EFd 5 | tail -2 >> ${MOR}
