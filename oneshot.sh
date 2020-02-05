#!/bin/bash
shopt -s extglob
#
# oneshot: score original model
#
# External software requirements: ROCKER and ShaEP installed in the path.

function usage_and_exit ()
{
    echo "Usage: oneshot.sh options"
    echo "Options:"
    echo "-m input_nib.mol2,   A cavity-based NIB model from PANTHER (in MOL2 format)."
    echo "-l ligand_file.mol2, A ligand file with multiple docking poses for actives (LIG)"
    echo "                     and inactives from PLANTS (in MOL2 format)."
    echo "-s scoring,          Used scoring method. Optional. 'EF' or 'BR'.  BR can have a number."
    echo "                     Anything else selects AUC. Defaults to AUC."
    echo "-p prefix,           Prefix for generated directory names.  Optional.  Defaults to 'gen'."
    echo "--espweight number,  Shaep espweight.  Optional.  Defaults to 0.5."
    echo "--chunk number,      Ligand set is split to chunks to avoid memory exhaustion. Ligands per chunk. Optional.  Defaults to 100000."
    echo "-h|--help,           This text"
    exit 1
}

TEMP=$(getopt -o m:l:s:p:h -l espweight:,chunk:,help -n 'oneshot' -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"
MODEL=""
LIGANDS=""
SCORING="AUC"
PREFIX="gen"
ESPWEIGHT="0.5"
CHUNK=100000
while true ; do
        case "$1" in
                -l) LIGANDS="$2" ; shift 2 ;;
                -m) MODEL="$2"   ; shift 2 ;;
                -p) PREFIX="$2"  ; shift 2 ;;
                -s) SCORING="$2" ; shift 2 ;;
                --espweight) ESPWEIGHT="$2" ; shift 2 ;;
                --chunk) CHUNK="$2" ; shift 2 ;;
                -h|--help) usage_and_exit ;;
                --) shift ; break ;;
                *) echo "Internal error!" ; exit 1 ;;
        esac
done

# Must have model and ligand files
[[ -n "${MODEL}" && -n "${LIGANDS}" ]] || usage_and_exit

[[ -f part1.mol2 ]] || ${BRUTEBIN}/mol2split "${LIGANDS}" ${CHUNK}

GENERATION=0
WDIR=${PREFIX}${GENERATION}
mkdir ${WDIR}
VICTIM=1
MOF=model-g${GENERATION}-${VICTIM}.mol2
cp "${MODEL}" ${WDIR}/${MOF}
pushd ${WDIR}
for PLIC in ../part*.mol2
do
    ${BRUTEBIN}/nibscore.sh ${MOF} "${PLIC}" ${ESPWEIGHT}
done
${BRUTEBIN}/run_rocker.sh model-g${GENERATION}-${VICTIM}-rescore "${SCORING}"

popd
WINNER=${WDIR}/${MOF}

echo "The best pocket of generation ${GENERATION} was ${WINNER}"
cat ${WINNER%.mol2}-rescore_enrich.txt
ln -s ${WINNER} ${PREFIX}-${WINNER#${WDIR}/}

