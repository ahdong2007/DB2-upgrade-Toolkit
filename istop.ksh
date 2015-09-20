#!/bin/ksh

#
#  Mason Hua 2015/09/16 V0.1

#  
#  Usage: $0 [-i inst1,inst2,...]
#    with -i, must be run it as root
#    without -i, run it with instance id, stop current instance
#
#    Note: make sure every instance id have access to the working directory

export OS=`uname -s|tr [a-z] [A-Z]`

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
  stop )
    stop_instance ;;
esac

if [ `id -u` -ne 0 ]; then
  # instance id
  stop_instance
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
      su - $INST -c "$WPATH/$PROGM -t stop -i $INST"
    fi
  
    INST=`echo "$INSTS" | cut -d, -f $count`
    (( count=$count + 1 ))
  done

fi

exit 0

# End of istart
