#!/bin/ksh

#
#  Mason Hua 2015/09/22 V0.1

#  
#  Usage: $0 [-i inst1,inst2,...]
#    with -i, must be run it as root
#    without -i, run it with instance id, do HC for current instance
#
#    Note: make sure every instance id have access to the working directory

export OS=`uname -s | tr [a-z] [A-Z]`

SHOME="$HOME/Security/"
vfile="$SHOME/.vfile.rpt"
vtmp="$SHOME/.vtmp.out"

if [ `echo "$0" | grep -c '^\./'` -eq 1 ]; then
  # use it by this way: ./istop.ksh
  WPATH=`pwd`
  PROGM=${0#./}
else
  # use it with full path
  WPATH=${0%/*}
  PROGM=${0##*/}
fi

# if run it with root, make all instances have access to this script
if [ `id -u` -eq 0 ]; then
  chmod 755 $WPATH/$PROGM >/dev/null 2>&1
fi

# Functions
Usage ( )
{
  echo " "
  echo "Usage: $0 [-i <instances, use comma(,) to separate each instance>] 
                 
        a. When run it with root, -i is the mandatory parameter
        b. When run it with instance id, -i will be ignore

        Note: Make sure every instance have access to the work directory    
  "
  echo " "
  exit 1
}

# A020,A021,A026
#####################################################################
# DATABASE LEVEL                                                    #
#####################################################################
# Violation A020 -  Checking connect and impleschema  given on DB"
# Violation A021 -  Check any privilage given to schemas
# Violation A223 -  Check any privilage given to table SYSTOOLS.ADMINTASKS
# Violation A224 -  Check any privilage given to view SYSTOOLS.ADMIN_TASK_LIST
# Violation A225 - Check execute privilage given to  procedure SYSTOOLS.ADMIN_TASK_LIST

Fix_A020 ( ) 
{

# cat *.info | grep -w 'VIOLATION' | grep A020
# A020  |DBAUTH              |PUBLIC   |IMPLSCHEMA  |VIOLATION
# A020  |DBAUTH              |PUBLIC  |CONNECT     |VIOLATION

priv=`echo $1 | awk -F'|' '{print $4}' | awk 'gsub(" ","",$0)'`

if [ "$priv" == "CONNECT" ]; then
  cmd="db2 revoke CONNECT on database from PUBLIC"
fi

if [ "$priv" == "IMPLSCHEMA" ]; then
  cmd="db2 revoke IMPLICIT_SCHEMA on database from PUBLIC"
fi

db2 connect to $db_name
echo ${cmd} | tee -a $vscript
${cmd}
db2 terminate

} # end of Fix_A020

Fix_A021 ( ) 
{

# cat *.info | grep -w 'VIOLATION' | grep A021
# A021  |Schema-JEBRUNSG                            |PUBLIC           |CREATEIN           |VIOLATION
# A021  |Schema-JOUHAUD                             |PUBLIC           |CREATEIN           |VIOLATION
# A021  |Schema-SBROMANO                            |PUBLIC           |CREATEIN           |VIOLATION
# A021  |Schema-SYSPUBLIC                           |PUBLIC           |CREATEIN           |VIOLATION
# A021  |Schema-A3INSTMT     |PUBLIC  |CREATEIN    |VIOLATION
# A021  |Schema-DB2EXT       |PUBLIC  |CREATEIN    |VIOLATION

#cmd=`echo $1 | awk '{print $2 " " $3}' | sed 's/[\|]/ /g' | cut -d "-" -f2 | awk '{print "db2 revoke " $2 " on schema " $1 " from public" '}`
cmd=`echo $1 | awk '{print $2 " " $3}' | sed 's/[\|]/ /g' | cut -d "-" -f2 | awk '{print "db2 revoke CREATEIN on schema " $1 " from public" '}`

db2 connect to $db_name
echo ${cmd} | tee -a $vscript
${cmd}
db2 terminate

} # end of Fix_A021


Fix_A026 ( ) 
{

# cat *.info | grep -w 'VIOLATION' | grep A026
# A026  |SYSIBM.SYSSECURITYLABELCOMPONENTELEMENTS  |PUBLIC           |SELECT             |VIOLATION
# A026  |SYSIBM.SYSSECURITYLABELCOMPONENTS         |PUBLIC           |SELECT             |VIOLATION
# A026  |SYSIBM.SYSSECURITYLABELS                  |PUBLIC           |SELECT             |VIOLATION
# A026  |SYSIBM.SYSSECURITYPOLICIES                |PUBLIC           |SELECT             |VIOLATION
# A026  |SYSIBM.SYSSECURITYPOLICYCOMPONENTRULES    |PUBLIC           |SELECT             |VIOLATION


cmd=`echo $1 | awk '{print $2 " " $3}' | sed 's/[\|]/ /g' | cut -d "-" -f2 | awk '{print "db2 revoke select on table " $1 " from public" '}`

db2 connect to $db_name
echo ${cmd} | tee -a $vscript
${cmd}
db2 terminate

} # end of Fix_A026


# A045|A050|A055|A058|A060|A062|A065|A066|A070
# For A070, need root access
Fix_A065 ( )
{

# A065  |775                 |F:775  |db2c955  |staff   |/home/db2c955/javacore.20130709.222833.6684922.txt                  |VIOLATION-Grp
# A065  |775                 |F:775  |db2c955  |staff   |/home/db2c955/javacore.20130818.051948.2293832.txt                  |VIOLATION-Grp
# A065  |775  |F:775  |instptx1  |staff    |/home/instptx1/.profile                                                      |VIOLATION-Grp
# A065  |775  |F:666  |instptx1  |dbadmin  |/home/instptx1/core.20150412.075515.22741002.dmp                             |VIOLATION

echo "Fix_A065: 1: $1"
cmd=`echo $1 | grep -w 'VIOLATION' | egrep 'A045|A050|A055|A058|A060|A062|A065|A066|A070' | awk -F'|' '{print "chmod " $2 $6}'`

echo ${cmd} | tee -a $vscript
${cmd}

# for VIOLATION-Grp
cmd=`echo $1 | grep -w 'VIOLATION-Grp' | egrep 'A045|A050|A055|A058|A060|A062|A065|A066|A070' | awk -F'|' '{gsub(" ","",$4);print "chown "$4":"$5 $6}'`

echo ${cmd} | tee -a $vscript
${cmd}
}

# A070 only needed when run with root
#Fix_A070 ( )
#{

# A065  |775                 |F:775  |db2c955  |staff   |/home/db2c955/javacore.20130709.222833.6684922.txt                  |VIOLATION-Grp
# A065  |775                 |F:775  |db2c955  |staff   |/home/db2c955/javacore.20130818.051948.2293832.txt                  |VIOLATION-Grp
# A065  |775  |F:775  |instptx1  |staff    |/home/instptx1/.profile                                                      |VIOLATION-Grp
# A065  |775  |F:666  |instptx1  |dbadmin  |/home/instptx1/core.20150412.075515.22741002.dmp                             |VIOLATION


# echo "Fix_A065: 1: $1"
# cmd=`echo $1 | grep -w 'VIOLATION' | egrep 'A045|A050|A055|A058|A060|A062|A065|A066|A070' | awk -F'|' '{print "chmod " $2 $6}'`

# for VIOLATION-Grp
# cmd1=`echo $1 | grep -w 'VIOLATION-Grp' | egrep 'A045|A050|A055|A058|A060|A062|A065|A066|A070' | awk -F'|' '{gsub(" ","",$4);print "chown "$4":"$5 $6}'`

#}


# fix violations
fix_vio () {
  if [ "$INST" == "" ]; then
    INST=$USER
  fi
  
  cd $SHOME

  $SHOME/db2shc -nm
  hcfiles=$(ls $SHOME/*$hostname-$USER*.out)

  for hcfile in $hcfiles
  do
    viols=$(awk -F\| '/TOTAL VIOLATIONS/ { print $5 }' $hcfile)
    db_name=$(ls -l $hcfile | awk -F':' '{print $2}' | awk -F'-' '{print $5}')
    echo $db_name : $viols

    if [[ $viols -gt 0 ]]
    then
      echo "Violations before we run this script $db_name: totally $viols" | tee -a $vfile
      cat $SHOME/*$hostname-$USER-$db_name*.info | grep -w 'VIOLATION' | head -10 | tee -a $vfile
      echo "......" | tee -a $vfile
      echo ""       | tee -a $vfile
      echo "going to fix those violations for $db_name"
      cat $SHOME/*$hostname-$USER-$db_name*.info | grep -w 'VIOLATION' | tee $vtmp
      while read line
      do
        echo "line: $line"
        vtype=`echo $line | awk -F'|' '{gsub(" ","",$1);print $1}'`
        echo "VIOLATION TYPE: $vtype"
        case $vtype in
          "A020") Fix_A020 "$line" ;;
          "A021") Fix_A021 "$line" ;;
          "A026") Fix_A026 "$line" ;;
          "A045"|"A050"|"A055"|"A058"|"A060"|"A062"|"A065"|"A066")  Fix_A065 "$line" ;;
          #"A070")  Fix_A070 "$line" ;;
        esac
      done < $vtmp
    else
      echo "No violations found for $db_name" | tee -a $vfile
    fi
  done

  # run it again
  $SHOME/db2shc -nm
  hcfiles=$(ls $SHOME/*$hostname-$USER*.out)

  for hcfile in $hcfiles
  do
    viols=$(awk -F\| '/TOTAL VIOLATIONS/ { print $5 }' $hcfile)
    db_name=$(ls -l $hcfile | awk -F':' '{print $2}' | awk -F'-' '{print $5}')
    echo $db_name : $viols

    if [[ $viols -gt 0 ]]
    then
      echo "Violations after we run this script $db_name: totally $viols" | tee -a $vfile
      cat $SHOME/*$hostname-$USER-$db_name*.info | grep -w 'VIOLATION' | head -10 | tee -a $vfile
      echo "......" | tee -a $vfile
      echo ""       | tee -a $vfile
    else
      echo "Violations after we run this script for $db_name: totally $viols" | tee -a $vfile
      echo "ALL violations fixed!!" | tee -a $vfile

      echo "cat $hcfile | grep -w 'TOTAL VIOLATIONS"
      cat $hcfile | grep -w 'TOTAL VIOLATIONS'
    fi
  done

  \rm $vfile 2>/dev/null
  \rm $vtmp  2>/dev/null

  exit 0
}

# end of fix violations

# End of functions

# Main function
OPTIND=1
while getopts ":t:i:" opt
do
  case ${opt} in
    t )  OPER=${OPTARG} ;;
    i )  INSTS=${OPTARG} ;;
  esac
done

case $OPER in
  fix_vio )
    fix_vio ;;
esac

if [ `id -u` -ne 0 ]; then
  # instance id
  fix_vio
else
  # root
  if [ "$INSTS" == "" ]; then
    Usage
    exit 1
  fi

  INSTS=${INSTS},
  count=2
  INST=`echo "$INSTS" | cut -d, -f 1`

  while [ "$INST" != "" ]
  do

    INST=`echo $INST | tr [A-Z] [a-z]`

    id $INST
    if [ $? -ne 0 ]; then 
      echo "Instance $INST is not exists, please check it!!!"
    else
      su - $INST -c "$WPATH/$PROGM -t fix_vio -i $INST"
    fi
  
    INST=`echo "$INSTS" | cut -d, -f $count`
    (( count=$count + 1 ))
  done

fi

exit 0

# End of istart
