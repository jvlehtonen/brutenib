#!/bin/bash
shopt -s extglob
#
# Brutetype
#
# Description: Generates a model that has modified atom types.
# Program generates two new models per atom in input_nib.mol2.
# Same position will have C, N, and O in related models.
# There is only one atom changed in each new model.
# The scores of models that differ in same position are compared,
# and atom type of best is copied to a final model.
#
# Requires that brutenib.sh has been run; will read score of the
# input model from directory gen0.
#
# Final model (and score) will be written to directory type1.
#
# USAGE: ./brutetype.sh input_nib.mol2 ligand_file.mol2 [slurm|number [EF|BRn]]
# Input #1 A cavity-based NIB model from PANTHER (in MOL2 format).
# Input #2 A ligand file with multiple docking poses for actives (LIG) and inactives from PLANTS (in MOL2 format).
# Input #3 Either word "slurm" or the number of processors to be used in the ShaEP-based NIB rescoring.  Optional.  Defaults to 4.
# Input #4 Used scoring method. Optional.  Defaults to AUC. 'EF' or 'BR'. BR can have a number. Anything else selects AUC.

# External software requirements: ROCKER and ShaEP installed in the path.

ROCKER="rocker"

[[ $# -lt 2 ]] && exit 1

NIB=$1
WHOLELIC=$2

GENERATION=0
WDIR=gen${GENERATION}
VICTIM=1
MOF=model-g${GENERATION}-${VICTIM}.mol2
OPT="-an LIG -c 2 -lp -las 20 -ts 18 -nro"
if [[ -n "${4}" ]]
then
    if [[ "${4}x" = "BRx" ]]
    then
	BRA=20
    else
	BRA=${4#BR}
    fi
fi

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

    BEST=${SCORE}
    WDIR=type${GENERATION}
    mkdir ${WDIR}
    HEADER=$(grep -n ATOM "${NIB}" | cut -d: -f1)
    NUM=$(tail -n +$[1 + ${HEADER}] "${NIB}" | grep -c -v "^$")
    [[ "$NUM" -lt 2 ]] && exit 0

    # Prepare pockets
    for (( VICTIM=1; VICTIM<=${NUM}; ++VICTIM ))
    do
	MOF=model-g${GENERATION}-${VICTIM}.mol2
	sed "${HEADER} q;" "${NIB}" > ${WDIR}/${MOF}
	tail -n +$[1 + ${HEADER}] "${NIB}" | sed "${VICTIM} y/CNO/NOC/" >> ${WDIR}/${MOF}

	THIRD=$[${NUM} + ${VICTIM}]
	MOG=model-g${GENERATION}-${THIRD}.mol2
	sed "${HEADER} q;" "${NIB}" > ${WDIR}/${MOG}
	tail -n +$[1 + ${HEADER}] ${WDIR}/${MOF} | sed "${VICTIM} y/CNO/NOC/" >> ${WDIR}/${MOG}
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
		../nibscore.sh ${GENERATION} "${PLIC}" $[${NUM} + ${VICTIM}] &
		NPROC=$[NPROC + 1]
		if [[ "$NPROC" -ge ${3:-4} ]]; then
		    wait
		    NPROC=0
		fi
	    done
	    wait
	fi
    done

    for (( VICTIM=1; VICTIM<=$[${NUM} + ${NUM}]; ++VICTIM ))
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

    WWDIR=type1
    mkdir ${WWDIR}
    sed "${HEADER} q;" "${NIB}" > "${WWDIR}/model-g1-1.mol2"
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
	THIRD=$[${NUM} + ${VICTIM}]
	case "${4}" in
	    'EF')
		EG=$(sed -n "s/EF_1.0.*= //p" ${WDIR}/model-g${GENERATION}-${THIRD}-rescore_enrich.txt) ;;
	    BR*)
		EG=$(sed -n "s/BEDROC.*= //p" ${WDIR}/model-g${GENERATION}-${THIRD}-rescore_enrich.txt) ;;
	    *)
		EG=$(sed -n "/AUC/ {s/AUC=//; s/+-.*//; p}" ${WDIR}/model-g${GENERATION}-${THIRD}-rescore_enrich.txt) ;;
	esac
	if [[ 1 = $(echo $EF'>'$BEST | bc -l) ]] ; then
	    if [[ 1 = $(echo $EG'>'$EF | bc -l) ]] ; then
		sed -n "$[${VICTIM} + ${HEADER}] p" "${WDIR}/model-g${GENERATION}-${THIRD}.mol2" >> "${WWDIR}/model-g1-1.mol2"
	    else
		sed -n "$[${VICTIM} + ${HEADER}] p" "${WDIR}/model-g${GENERATION}-${VICTIM}.mol2" >> "${WWDIR}/model-g1-1.mol2"
	    fi
	elif [[ 1 = $(echo $EG'>'$BEST | bc -l) ]] ; then
	    sed -n "$[${VICTIM} + ${HEADER}] p" "${WDIR}/model-g${GENERATION}-${THIRD}.mol2" >> "${WWDIR}/model-g1-1.mol2"
	else
	    sed -n "$[${VICTIM} + ${HEADER}] p" "${NIB}" >> "${WWDIR}/model-g1-1.mol2"
	fi
    done

    GENERATION=1
    pushd ${WWDIR}
    VICTIM=1
    for PLIC in ../part*.mol2
    do
	../nibscore.sh ${GENERATION} "${PLIC}" ${VICTIM}
    done

    MOT=model-g${GENERATION}-${VICTIM}-rescore
    MOR=${MOT}_enrich.txt
    awk -f ../trim-shaep.awk ${MOT}.txt > ${MOT}-trim.txt
    #
    OPT="-an LIG -c 2 -lp -las 20 -ts 18 -nro"
    #
    ${ROCKER} ${MOT}-trim.txt ${OPT} -EFd 1 | grep -v Loaded > ${MOR}
    ${ROCKER} ${MOT}-trim.txt ${OPT} -BR ${BRA} -EFd 5 | tail -2 >> ${MOR}
    popd
    cat ${WWDIR}/model-g1-1-rescore_enrich.txt
