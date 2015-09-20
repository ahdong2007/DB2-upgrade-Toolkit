#!/bin/ksh

#
#  Mason Hua 2015/09/16 V0.1

#  
#  Usage: $0 -i inst1,inst2,...
#            -b <the code path you use to upgrade the instances> 
#            -l <license file with full path>
#
#         Must run it as root
#

export OS=`uname -s | tr [a-z] [A-Z]`

if [ `echo "$0" | grep -c '^\./'` -eq 1 ]; then
  # use it by this way: ./istop.ksh
  WPATH=`pwd`
  PROGM=${0#./}
else
  # use it with full path
  WPATH=${0%/*}
  PROGM=${0##*/}
fi

# Functions
Usage ( )
{
  echo " "
  echo "Run it as root "
  echo "Usage: $0 -i <instances, use comma(,) to separate each instance> 
                  -b <the code path you use to upgrade the instances> 
                  -l <license file with full path>
        Mandatory parameters:
	          -i, -b
        Note: Make sure every instance have access to the work directory    
  "
  echo " "
  exit 1
}

# stop_instance
stop_instance ( ) {
  if [ "$INST" == "" ]; then
    INST=$USER
  fi

  echo "Going to stop instance $INST ..."

  if [ `ps -ef | grep db2sys | grep -i -w $INST | grep -cv grep` -ge 1 ]; then
    echo "stopping Instances $INST"
    if [[ $OS == "AIX" ]]; then
      db2 force application all
      db2 force application all
      for db in `db2 list db directory | grep -p 'Indirect'  | grep 'Database alias' | awk -F'=' '{print $2}'`
      do
        db2 deactivate db $db
      done
      db2stop force && ipclean 
    else
      db2 force application all
      db2 force application all
      for db in `db2 list db directory | grep -B 5 'Indirect'  | grep 'Database alias' | awk -F'=' '{print $2}'`
      do
        db2 deactivate db $db
      done
      db2stop force && ipclean 
    fi
  else
    echo "No db2 instance running in current id: $INST"
  fi
 
  echo " "
  echo "Check if db2sys process exists ..."
  ps -ef | grep db2sys | grep $USER | grep -v grep
  exit 0
}
# end of stop instance

# upgrade instance
update_instance () {
  if [ "$INST" ==  "" ]; then
    echo "-i <instances> is mandatory when calling upgrade instance"
    Usage
  fi

  if [ "$CPATH" ==  "" ]; then
    echo "-b <code path> is mandatory when calling upgrade instance"
    Usage
  fi
  echo "updating instance: $INST"

  if [[ -f $CPATH/instance/db2iupdt ]]; then
    echo "$CPATH/instance/db2iupdt -k $INST"
    $CPATH/instance/db2iupdt -k $INST
  else
    echo "db2iupdt is not exist on $CPATH/instance..."
    exit 1
  fi
  echo "end of update instance: $INST"
  
}
# end of upgrade_instance

# apply license
apply_license () {
  if [ -f "$LFILE" ]; then
    echo "apply license"
    echo "$CPATH/adm/db2licm -a $LFILE"
    $CPATH/adm/db2licm -a $LFILE
  fi
}
# end of apply_license

# End of functions
# Main function
OPTIND=1
while getopts ":t:b:i:l:" opt
do
  case ${opt} in
    t )  OPER=${OPTARG} ;;
    b )  CPATH=${OPTARG} ;;
    i )  INSTS=${OPTARG} ;;
    l )  LFILE=${OPTARG} ;;
  esac
done

case $OPER in
  stop )
    stop_instance ;;
  update )
    update_instance ;;
  apply_license )
    apply_license ;;
esac

# if run it with root, make all instances have access to this script
if [ `id -u` -eq 0 ]; then
  chmod 755 $WPATH/$PROGM >/dev/null 2>&1
else
  Usage
  exit 1
fi

# check parameters
if [ "$CPATH" == "" ]; then
  echo "-b is mandatory for updating instance"
  Usage
fi

if [ "$LFILE" == "" ]; then
  echo "No license file provided, will not apply license"
  echo "Pls apply it manually if needed"
fi

if [ "$INSTS" == "" ]; then
  echo "-i is mandatory for updating instance"
  Usage
fi

# End of check parameters


# main function
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
    # stop instances before update instance
    su - $INST -c "$WPATH/$PROGM -t stop -i $INST"
    update_instance
  fi
  
  INST=`echo "$INSTS" | cut -d, -f $count`
  (( count=$count + 1 ))
done

apply_license

exit 0

# End of main function

# End of istart
