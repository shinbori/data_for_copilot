#!/bin/bash
#
# Usage:
#   mk_efd_l2p_spec_cdf.sh 20181109 
#   mk_efd_l2p_spec_cdf.sh -v r00-v00-00 20181109 
#

# Options
while getopts v: OPT
do
  case $OPT in
    "v" ) FLG_V="TRUE" ; verstr="$OPTARG" ;;
  esac
done
shift `expr $OPTIND - 1`

# Show the usage and end unless any argument is given
if [ $# -lt 1 ]; then
    echo "Usage:"
    echo `basename $0`" 20181109"
    exit 0
fi

# Set environmental variables for IDL
source ~/.bash_path

# Set versionstr if -v is given with a version string
if [ ${FLG_V} -a -n ${verstr} ]; then
  verstrkw=", versionstr='${verstr}'"
else
  verstrkw=""
fi


TMP_IDLPRO="tmp_efd_l2pspeccdf_$$.pro"
for ymd in $* ; do

    echo $ymd    
    cat <<_EOF_ >${TMP_IDLPRO}

makecdf_mmo_pwi_efd_l2p_spec, ${ymd} ${verstrkw}, /debug, outcdfdir='~/work_local/mmodata/cdf/pwi/efd/l2pre/spec/'
exit

_EOF_

    #cat ${TMP_IDLPRO}   # Uncomment for debug
    nice -n8 idl ${TMP_IDLPRO}
    /bin/rm -f ${TMP_IDLPRO} >/dev/null 2>&1

done





