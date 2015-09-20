#!/bin/ksh

#
#  Mason Hua 2015/09/16 V0.1

#  
#  Usage: $0 [-i inst1,inst2,...]
#    with -i, must be run it as root
#    without -i, run it with instance id, start current instance
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


# start instance
start_instance() {
  if [ "$INST" == "" ]; then
    INST=$USER
  fi

  echo "Going to start instance $INST ..."

  if [ `ps -ef | grep db2sys | grep -i -w $INST | grep -cv grep` -lt 1 ]; then
    db2start
  
    if [[ $OS == "AIX" ]]; then
      for db in `db2 list db directory | grep -p 'Indirect' | grep 'Database name' | sort -u | awk -F'=' '{print $2}'`
      do
        db2 activate db $db
      done
    else
      for db in `db2 list db directory | grep -B 5 'Indirect' | grep 'Database name' | sort -u | awk -F'=' '{print $2}'`
      do
        db2 activate db $db
      done
    fi
  else
    echo "Instance $INST is already running, no need to start it ..."

  fi

  echo " "
  echo "db2sys processes ..."
  ps -ef | grep db2sys | grep $USER | grep -v grep

  exit 0
}

# end of start instance

# function rebind
rebind () {
 
  if [ "$INST" == "" ]; then
    INST=$USER
  fi

  if [[ $OS == "AIX" ]]; then
    if [ `db2 list db directory | grep -p 'Indirect' | grep -c 'Database name'` -eq 0 ]; then
      echo "No database in this instance $USER"
      echo "No rebind is needed"
      exit 0
    fi
  else
    if [ `db2 list db directory | grep -B 5 'Indirect' | grep -c 'Database name'` -eq 0 ]; then
      echo "No database in this instance $USER"
      echo "No rebind is needed"
      exit 0
    fi
  fi

  echo "Going to rebind on databases in Instance: $INST"
  if [[ $OS == "AIX" ]]; then
    for db in `db2 list db directory | grep -p 'Indirect'  | grep 'Database alias' | awk -F'=' '{print $2}'`
    do
      cd $HOME/sqllib/bnd
      db2 connect to $db
      db2 bind  db2schema.bnd blocking all grant public SQLERROR continue 
      db2 bind  @db2ubind.lst BLOCKING ALL sqlerror continue grant public 
      db2 bind  @db2cli.lst blocking all grant public action add   

    # for capture and apply
      db2 bind @capture.lst isolation ur blocking all
      db2 bind @applycs.lst isolation cs blocking all grant public
      db2 bind @applyur.lst isolation ur blocking all grant public
    
    # for Qcapture and Qapply
      db2 bind @qcapture.lst isolation ur blocking all
      db2 bind @qapply.lst isolation ur blocking all grant public
      db2 terminate
    done
  else
    for db in `db2 list db directory | grep -B 5 'Indirect'  | grep 'Database alias' | awk -F'=' '{print $2}'`
    do
      cd $HOME/sqllib/bnd
      db2 connect to $db
      db2 bind  db2schema.bnd blocking all grant public SQLERROR continue 
      db2 bind  @db2ubind.lst BLOCKING ALL sqlerror continue grant public 
      db2 bind  @db2cli.lst blocking all grant public action add   

      # for capture and apply
      db2 bind @capture.lst isolation ur blocking all
      db2 bind @applycs.lst isolation cs blocking all grant public
      db2 bind @applyur.lst isolation ur blocking all grant public
    
      # for Qcapture and Qapply
      db2 bind @qcapture.lst isolation ur blocking all
      db2 bind @qapply.lst isolation ur blocking all grant public
      db2 terminate
    done
  fi

  exit 0
}
# end of rebind

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
  start )
    start_instance ;;
  rebind )
    rebind ;;
esac

if [ `id -u` -ne 0 ]; then
  # instance id
  start_instance
  rebind
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
      su - $INST -c "$WPATH/$PROGM -t start -i $INST"
      su - $INST -c "$WPATH/$PROGM -t rebind -i $INST"
    fi
  
    INST=`echo "$INSTS" | cut -d, -f $count`
    (( count=$count + 1 ))
  done

fi

exit 0

# End of istart
