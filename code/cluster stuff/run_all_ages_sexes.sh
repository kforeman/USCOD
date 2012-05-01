#!/bin/sh

MODEL_NAME="test"
DRAWS=20000
BURN=10000
LENGTH=200
CODE="${HOME}/python_code/GPR_model.py"

WALLTIME="2:00:00"
MEM="2000mb"
NCPUS=4


for a in "Under5" "5to14" "15to29" "30to44" "45to59" "60to74" "75plus"
	do
	for s in 1 2
		do
			echo "#!/bin/sh"								>  ${HOME}/run_files/tmp/run_${MODEL_NAME}_${a}_${s}
			echo "#PBS -l walltime=${WALLTIME}"				>> ${HOME}/run_files/tmp/run_${MODEL_NAME}_${a}_${s}
			echo "#PBS -l mem=${MEM}"						>> ${HOME}/run_files/tmp/run_${MODEL_NAME}_${a}_${s}
			echo "#PBS -l ncpus=${NCPUS}"					>> ${HOME}/run_files/tmp/run_${MODEL_NAME}_${a}_${s}
			echo "module load pymc/2012-04-25" 				>> ${HOME}/run_files/tmp/run_${MODEL_NAME}_${a}_${s}
			echo "python ${CODE} -a ${a} -s ${s} -n ${MODEL_NAME} -d ${DRAWS} -b ${BURN} -l ${LENGTH} > ${HOME}/logs/log_${MODEL_NAME}_${a}_${s}.log"	>> ${HOME}/run_files/tmp/run_${MODEL_NAME}_${a}_${s}
			qsub -q pqeph -o ${HOME}/logs -e ${HOME}/logs ${HOME}/run_files/tmp/run_${MODEL_NAME}_${a}_${s}
		done
	done
