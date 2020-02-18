#!/bin/bash
shopt -s extglob
#
# Brute helper script
#
[[ -z "${ACTIVENAME}" ]] && ACTIVENAME=CHEMBL

ROCKERBIN="${ROCKER:=rocker}"
OPT="${ACTIVENAME:+--activename ${ACTIVENAME} } ${ACTIVELIST:+--activename ${ACTIVELIST} } -c 2 -lp -las 20 -ts 18 -nro"

# echo "### ${ROCKERBIN} ${OPT} ###"

[[ $# -lt 1 ]] && exit 1

case "${2}" in
    'BR') BRA=20 ;;
    BR*)  BRA=${2#BR} ;;
    *)    ;;
esac

# Reduce Shaep output to two columns
MOT=$1
awk -f ${BRUTEBIN}/trim-shaep.awk ${MOT}.txt > ${MOT}-trim.txt
#
MOR=${MOT}_enrich.txt
${ROCKERBIN} ${MOT}-trim.txt ${OPT} -EFd 1 | grep -v Loaded > ${MOR}
${ROCKERBIN} ${MOT}-trim.txt ${OPT} -BR ${BRA} -EFd 5 | tail -2 >> ${MOR}
