#!/bin/bash
shopt -s extglob
#
# BruteNiB (Brute Force Negative Image-Based Rescoring)
#
# Description: The "BruteNiB script evaluates the impact of each cavity point (or atom) in a cavity-based negative image or 
# NIB model for the negative image-based rescoring (R-NiB) of explicit PLANTS docking poses. If the removal of any 
# of the points/atoms improves the R-NiB yield, the corresponding line is removed from the NIB model permanently. The iterative
# remove & evaluate process with the outputted model is done to each point/atom using a systematic brute force approach. 

# USAGE: ./brutenib.sh input_nib.mol2 ligand_file.mol2 [slurm|number [EF|BRn]]
# Input #1 A cavity-based NIB model from PANTHER (in MOL2 format).
# Input #2 A ligand file with multiple docking poses for actives (LIG) and inactives from PLANTS (in MOL2 format).
# Input #3 Either word "slurm" or the number of processors to be used in the ShaEP-based NIB rescoring.  Optional.  Defaults to 4.
# Input #4 Used scoring method. Optional.  Defaults to AUC. 'EF' or 'BR'. BR can have a number. Anything else selects AUC.

# External software requirements: ROCKER and ShaEP installed in the path.

#ROCKER="python /site/app7/rocker/0.1.1/rocker.pyc"
ROCKER="rocker"

[[ $# -lt 2 ]] && exit 1

NIB=$1
WHOLELIC=$2
./mol2split "${WHOLELIC}" 100000

GENERATION=0
WDIR=gen${GENERATION}
mkdir ${WDIR}
VICTIM=1
MOF=model-g${GENERATION}-${VICTIM}.mol2
cp "${NIB}" ${WDIR}/${MOF}
pushd ${WDIR}
for PLIC in ../part*.mol2
do
    if [[ "x${3}" = "xslurm" ]]
    then sbatch --wait ../nibscore.sh ${GENERATION} "${PLIC}" ${VICTIM}
    else ../nibscore.sh ${GENERATION} "${PLIC}" ${VICTIM}
    fi
done
MOT=model-g${GENERATION}-${VICTIM}-rescore
MOR=${MOT}_enrich.txt
# Reduce Shaep output to two columns
awk -f ../trim-shaep.awk ${MOT}.txt > ${MOT}-trim.txt
#
OPT="-an LIG -c 2 -lp -las 20 -ts 18 -nro"
#
# ${ROCKER} ${MOT}-trim.txt ${OPT} -la 'Decoys found' 'Actives found' -p AUC-g${GEN}.png | grep AUC > ${MOR}
# ${ROCKER} ${MOT}-trim.txt ${OPT} -la 'Decoys found' 'Actives found' -EFd 1 -p EFd_1-g${GEN}.png | grep EF >> ${MOR}
# ${ROCKER} ${MOT}-trim.txt ${OPT} -la 'Decoys found' 'Actives found' -EFd 5 -p EFd_5-g${GEN}.png | grep EF >> ${MOR}
if [[ -n "${4}" ]]
then
    if [[ "${4}x" = "BRx" ]]
    then
	BRA=20
    else
	BRA=${4#BR}
    fi
fi

${ROCKER} ${MOT}-trim.txt ${OPT} -EFd 1 | grep -v Loaded > ${MOR}
${ROCKER} ${MOT}-trim.txt ${OPT} -BR ${BRA} -EFd 5 | tail -2 >> ${MOR}
popd
WINNER=${WDIR}/${MOF}

case "${4}" in
    'EF')
	echo "Rank by EFd 1"
	SCORE=$(sed -n "s/EF_1.0.*= //p" ${WDIR}/model-g${GENERATION}-${VICTIM}-rescore_enrich.txt) ;;
    BR*)
	echo "Rank by BR ${BRA}"
	SCORE=$(sed -n "s/BEDROC.*= //p" ${WDIR}/model-g${GENERATION}-${VICTIM}-rescore_enrich.txt) ;;
    *)
	echo "Rank by AUC"
	SCORE=$(sed -n "/AUC/ {s/AUC=//; s/+-.*//; p}" ${WDIR}/model-g${GENERATION}-${VICTIM}-rescore_enrich.txt) ;;
esac
echo "The best pocket of generation ${GENERATION} was ${WINNER}"
cat ${WINNER%.mol2}-rescore_enrich.txt
ln -s ${WINNER} .

# Test max 50 generations
while [[ ${GENERATION} -lt 50 ]]
do
    BEST=${SCORE}
    CAND=${WINNER}
    GENERATION=$[GENERATION + 1]
    WDIR=gen${GENERATION}
    mkdir ${WDIR}
    NIB=${WINNER}
    HEADER=$(grep -n ATOM "${NIB}" | cut -d: -f1)
    NUM=$(tail -n +$[1 + ${HEADER}] "${NIB}" | grep -c -v "^$")
    [[ "$NUM" -lt 2 ]] && exit 0

    NEW=$[NUM - 1]
    # Prepare pockets
    for (( VICTIM=1; VICTIM<=${NUM}; ++VICTIM ))
    do
	MOF=model-g${GENERATION}-${VICTIM}.mol2
	# echo "#### ${VICTIM} #### ${MOF}"
	sed "${HEADER} q; s/ *${NUM} */ ${NEW}/" "${NIB}" > ${WDIR}/${MOF}
	tail -n +$[1 + ${HEADER}] "${NIB}" | sed "${VICTIM} d" >> ${WDIR}/${MOF}
    done
    # Rescore pockets
    pushd ${WDIR}
    for PLIC in ../part*.mol2
    do
	if [[ "x${3}" = "xslurm" ]] ; then
	    sbatch --wait --array=1-${VICTIM} ../nibscore.sh ${GENERATION} "${PLIC}"
	else
	    NPROC=0
	    for (( VICTIM=1; VICTIM<=${NUM}; ++VICTIM ))
	    do
		../nibscore.sh ${GENERATION} "${PLIC}" ${VICTIM} &
		NPROC=$[NPROC + 1]
		if [[ "$NPROC" -ge ${3:-4} ]]; then
		    wait
		    NPROC=0
		fi
	    done
	    wait
	fi
    done

    for (( VICTIM=1; VICTIM<=${NUM}; ++VICTIM ))
    do
	MOT=model-g${GENERATION}-${VICTIM}-rescore
	MOR=${MOT}_enrich.txt
	awk -f ../trim-shaep.awk ${MOT}.txt > ${MOT}-trim.txt
	#
	OPT="-an LIG -c 2 -lp -las 20 -ts 18 -nro"
	#
	${ROCKER} ${MOT}-trim.txt ${OPT} -EFd 1 | grep -v Loaded > ${MOR}
	${ROCKER} ${MOT}-trim.txt ${OPT} -BR ${BRA} -EFd 5 | tail -2 >> ${MOR}
    done
    popd

    # Find best pocket in generation
    CAND=""
    for (( VICTIM=1; VICTIM<=${NUM}; ++VICTIM ))
    do
	case "${4}" in
	    'EF')
		EF=$(sed -n "s/EF_1.0.*= //p" ${WDIR}/model-g${GENERATION}-${VICTIM}-rescore_enrich.txt) ;;
	    BR*)
		EF=$(sed -n "s/BEDROC.*= //p" ${WDIR}/model-g${GENERATION}-${VICTIM}-rescore_enrich.txt) ;;
	    *)
		EF=$(sed -n "/AUC/ {s/AUC=//; s/+-.*//; p}" ${WDIR}/model-g${GENERATION}-${VICTIM}-rescore_enrich.txt) ;;
	esac
	if [[ 1 = $(echo $EF'>'$BEST | bc -l) ]] ; then
	    BEST=${EF}
	    CAND=${WDIR}/model-g${GENERATION}-${VICTIM}.mol2
	fi
    done

    # Did we beat the previous generation?
    if [[ -n "${CAND}" ]]
    then
	SCORE=${BEST}
	WINNER=${CAND}
	echo "The best pocket of generation ${GENERATION} was ${WINNER}"
	cat ${WINNER%.mol2}-rescore_enrich.txt
	ln -s ${CAND} .
	WINP=${CAND#*/}
	rm ${WDIR}/!(${WINP%.mol2})-rescore.txt  # Remove all but winner's shaep table
    else
	# No improvement
	echo "Final: ${WINNER}"
	exit 0
    fi
done


