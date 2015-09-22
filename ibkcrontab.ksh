#!/bin/ksh

#
#  Mason Hua 2015/09/22 V0.1

#  
#  Usage: $0 [-i inst1,inst2,...]
#            [-d <directory to save backups>]
#    with -i, must be run it as root
#    without -i, run it with instance id, backup crontab for current instance
#
#    Note: make sure every instance id have access to the working directory

export OS=`uname -s|tr [a-z] [A-Z]`

if [ `echo "$0" | grep -c '^\./'` -eq 1 ]; then
  # use it by this way: ./$0
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
                  [-d <directory to save backups>]
                  [-a <[backup | comment | restore]>]
        a. When run it with root, -i is the mandatory parameter
        b. When run it with instance id, -i will be ignore

        Note: Make sure every instance have access to the work directory    
  "
  echo " "
  exit 1
}


# bk_crontab
bk_crontab () {
  if [ "$INST" == "" ]; then
    INST=$USER
  fi

  # if -d option is not provide, backup crontab to instance home
  if [ "$BKPATH" == "" ]; then
    BKPATH=$HOME
  fi

  BKFILE="crontab.${INST}.`date "+%Y%m%d%H%M%S"`.bak"
  echo "Going to backup crontab for instance $INST to $BKPATH ..."

  crontab -l > $BKPATH/$BKFILE
  if [ $? -ne 0 ]; then
    echo "Backup crontab for user $INST failed ..."
    echo "Check if crontab was empty !!"
    exit 1
  fi

  ls -l $BKPATH/$BKFILE

  exit 0
}

# end of bk_crontab

# comment out crontab
comment_out_crontab () {

  if [ "$INST" == "" ]; then
    INST=$USER
  fi

  # if -d option is not provide, backup crontab to instance home
  if [ "$BKPATH" == "" ]; then
    BKPATH=$HOME
  fi

  BKFILE="crontab.${INST}.`date "+%Y%m%d%H%M%S"`.before_comment.bak"
  echo "Going to backup crontab for instance $INST to $BKPATH before comment out crontab ..."

  crontab -l > $BKPATH/$BKFILE

  if [ $? -ne 0 ]; then
    echo "Backup crontab for user $INST failed ..."
    echo "Check if crontab was empty !!"
    exit 1
  fi

  ls -l $BKPATH/$BKFILE

  echo ""
  echo "Going to comment out crontab for user: $INST ..."
  TMP_BKFILE=".${BKFILE}.tmp"
  sed -e 's/\(^.*$\)/#\1/' $BKPATH/$BKFILE > $BKPATH/$TMP_BKFILE

  echo "empty crontab first with : crontab -r"
  crontab -r
  echo "reload crontab with commented items:"
  crontab $BKPATH/$TMP_BKFILE

  echo "List current crontab:"
  crontab -l

  \rm $BKPATH/$TMP_BKFILE

  exit 0

}
# end of comment out crontab

# restore crontab
restore_crontab () {

  if [ "$INST" == "" ]; then
    INST=$USER
  fi

  # if -d option is not provide, backup crontab to instance home
  if [ "$BKPATH" == "" ]; then
    BKPATH=$HOME
  fi

  BKFILE="crontab.${INST}.`date "+%Y%m%d%H%M%S"`.before_restore.bak"
  echo "Going to backup crontab for instance $INST to $BKPATH before restore crontab ..."

  crontab -l > $BKPATH/$BKFILE

  if [ $? -ne 0 ]; then
    echo "Backup crontab for user $INST failed ..."
    echo "Check if crontab was empty !!"
    exit 1
  fi

  ls -l $BKPATH/$BKFILE

  echo ""
  echo "Going to restore crontab for user: $INST ..."
  TMP_BKFILE=".${BKFILE}.tmp"
  sed -e 's/^#//' $BKPATH/$BKFILE > $BKPATH/$TMP_BKFILE

  echo "empty crontab first with : crontab -r"
  crontab -r
  echo "reload crontab with uncommented items:"
  crontab $BKPATH/$TMP_BKFILE

  echo "List current crontab:"
  crontab -l

  \rm $BKPATH/$TMP_BKFILE

  exit 0

}

# end of restore crontab

# End of functions

# Main function
OPTIND=1
while getopts ":t:i:d:a:" opt
do
  case ${opt} in
    t )  OPER=${OPTARG} ;;
    i )  INSTS=${OPTARG} ;;
    d )  BKPATH=${OPTARG} ;;
    a )  ACTION=${OPTARG} ;;
  esac
done

case $OPER in
  bk_crontab )
    bk_crontab ;;
  comment_out_crontab )
    comment_out_crontab ;;
  restore_crontab )
    restore_crontab ;;
esac

if [ `id -u` -ne 0 ]; then
  # instance id
  case $ACTION in
        backup )
          bk_crontab ;; 
        comment )
          comment_out_crontab ;;
        restore )
          restore_crontab ;;
        * )
          Usage ;;
  esac
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

echo "action: $ACTION"
    id $INST > /dev/null 2>&1
    if [ $? -ne 0 ]; then 
      echo "Instance $INST is not exists, please check it!!!"
    else
      case $ACTION in
        backup )
          su - $INST -c "$WPATH/$PROGM -t bk_crontab -i $INST -d $BKPATH" ;;
        comment )
          su - $INST -c "$WPATH/$PROGM -t comment_out_crontab -i $INST -d $BKPATH" ;;
        restore )
          su - $INST -c "$WPATH/$PROGM -t restore_crontab -i $INST -d $BKPATH" ;;
        * )
          Usage ;;
      esac
    fi
  
    INST=`echo "$INSTS" | cut -d, -f $count`
    (( count=$count + 1 ))
  done

fi

exit 0

# End of istart
