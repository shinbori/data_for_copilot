#!/bin/bash 

## Usage
# unix> cron_mk_efd_l2pre_spec.sh  
# unix> cron_mk_efd_l2pre_spec.sh all  (to reprocess all files) 

# src: ~/work_local/data_org/bc/mmo/pwi/efd/l1/2018/mmo_pwi_efd_l1_Spec_L_20181109_v00.cdf
# dest: /var/www/html/data/chs/satellite/mmo/cdf/pwi/efd/l2pre/spec/2018/11/bc_mmo_pwi_efd_l1_spec_L_20181109_r00-v00-00.cdf
#       --> ~/work_local/mmodata/cdf/pwi/efd/l2pre/spec/2021/11/bc_mmo_pwi_efd_l2p_l_spec_20181109_r00-v00-00.cdf


## Suppress duplicated runs
CMDLINE=$(cat /proc/$$/cmdline | xargs --null)
if [[ $$ -ne $(pgrep -oxf "${CMDLINE}") ]]; then
  #echo "Already running!" >&2
  exit 9 >/dev/null 2>&1
fi

date 

# The working directory where this process is executed
WDIR=~/work_local/data_pipeline/mmo/pwi/efd/efd_spec
cd ${WDIR}

# Data paths
L1PATH=~/work_local/data_org/bc/mmo/pwi/efd/l1
L2PREPATH=~/work_local/mmodata/cdf/pwi/efd/l2pre/spec

# Version numbers of Lv.1 data and Lv.2pre data
L1V=01
L2REL=01
L2MJR=00
L2MNR=00

L2VER=r${L2REL}-v${L2MJR}-${L2MNR}   # e.g., r01-v00-00


# allupdate?
[ "$1" == "all" ] && allupdate=1 || allupdate=0


# Survey the existing Lv.1 CDF files to generate the date list
ymdlist=( `( for i in ${L1PATH}/????/mmo_pwi_efd_l1_Spec_L_????????_v${L1V}.cdf ; do basename $i | sed s/mmo_pwi_efd_l1_Spec_L_// | cut -b 1-8 ; done ) | sort | uniq` )

# Loop for generating a Lv2 CDF file
for ymd in ${ymdlist[@]} ; do
 
   date

   # Skip generating a file before 20181001
   if [ ${ymd} -lt 20181001 ]; then
     continue
   fi

   yyyy=`echo ${ymd} | cut -b 1-4`
   mm=`echo ${ymd} | cut -b 5-6`

   src_file=`ls -t ${L1PATH}/${yyyy}/mmo_pwi_efd_l1_Spec_L_${ymd}_v${L1V}.cdf 2>/dev/null | sort | tail -1`
   
   target_file=`ls -t ${L2PREPATH}/${yyyy}/${mm}/bc_mmo_pwi-efd_l2p_l_spec_${ymd}_${L2VER}.cdf 2>/dev/null | head -1`
   [ -z ${target_file} ] && target_file=${L2PREPATH}/${yyyy}/${mm}/bc_mmo_pwi-efd_l2p_l_spec_${ymd}_${L2VER}.cdf

   # Remove the target CDF file if allupdate is set.
   [ ${allupdate} -ne 0 ] && echo "allupdate is ON ... `basename ${target_file}` is removed" 
   [ ${allupdate} -ne 0 ] && /bin/rm -f ${target_file} > /dev/null 2>&1 
  
   echo "Source files: "${src_file}
   echo "Target files: "${target_file}
 
   make -f - << _EOF_
${target_file}: ${src_file}
	${WDIR}/mk_efd_l2p_spec_cdf.sh -v ${L2VER} ${ymd}
_EOF_

   echo ""

done

echo "" ; echo "$0 completed."
date






