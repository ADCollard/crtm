#!/bin/sh

#EXE_FILE=/jcsda/save/wx23yc/TauRegress/ODPS/ODAS_WLO_Regress/gencoef

#gen_optran_coeff.sh ALLCOM tau_coeff.parameters $EXE_FILE

optran_get_stat.sh tau_coeff.parameters

#EXE_file=${HOME}/gen_tau_coeff_varyingOrder/bin/Cat_tauCoeff
EXE_file=/jcsda/save/wx23yc/TauRegress/ODAS/Assemble_ODAS/Cat_ODAS
cat_optran_taucoef.sh tau_coeff.parameters $EXE_file

exit
