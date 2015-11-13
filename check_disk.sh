#!/bin/bash
# set -x
############################################################
# A script to check the available space of the various
# filesystems on a Linux server.
#
# Author: derrek.young@appdynamics.com
# Version: 1.1
#
############################################################

# The configuration file
. ./check_disk.cfg

# URL encode the data
urlencode() {
    # urlencode <string>
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%%%02X' "'$c"
        esac
    done
}

# Create the custom event via cURL
function send_custom_event {
  local level=$1
  local summary=$2
  local comment=$3
  local app=$(urlencode "$APPLICATION")

  local data="eventtype=CUSTOM&customeventtype=DiskSpace&summary=$summary&comment=$comment&severity=$level&propertynames=level&propertyvalues=$level"

  local curl_cmd="curl --user $USER:$PASSWORD --data \"$data\" $CONTROLLER_URL/controller/rest/applications/$app/events"

  if [ "$DEBUG" = true ] ; then
    echo "Sending cURL to create event."
    echo "level: $level"
    echo "summary: $summary"
    echo "comment: $comment"
    echo "data: $data"
    echo " "
    echo $curl_cmd
    echo " "
  fi

	eval $curl_cmd
  echo ""
}

# Compare the disk space used to the thresholds
function check_disk_used {
  while read output;
  do
    local filesystem=$(echo $output | awk '{print $1}')
    local size=$(echo $output | awk '{print $2}')
    local usep=$(echo $output | awk '{ print $5}' | cut -d'%' -f1)
    local partition=$(echo $output | awk '{print $6}')

    local message="Host: $HOSTNAME, Filesystem: $filesystem, Partition: $partition, Percent Used: $usep%, Application: $APPLICATION"

    if [ $usep -ge $CRITICAL_USED ] ; then
      if [ "$DEBUG" = true ] ; then
        echo "$output"
        echo "ERROR: $message"
      fi

      # Create the event but URL encode the data first
      send_custom_event "ERROR" $(urlencode "Disk space critical. $message") ""

    elif [ $usep -ge $WARNING_USED ] ; then
      if [ "$DEBUG" = true ] ; then
        echo "$output"
        echo "WARN: $message"
      fi

      # Create the event but URL encode the data first
      send_custom_event "WARN" $(urlencode "Disk space warning. $message") ""

    else
      if [ "$DEBUG" = true ] ; then
        echo "$output"
        echo "Filesystem is good."
        echo " "
      fi
    fi
  done
}

# Check the required variables are defined in diskspace.cfg
function check_variables {
  for var in WARNING_USED CRITICAL_USED CONTROLLER_URL USER PASSWORD APPLICATION MINUTE_FREQUENCY ; do
    if [ -n "${!var}" ] ; then
      if [ "$DEBUG" = true ] ; then
        echo "$var=${!var}"
      fi
    else
        echo "$var variable is required. Please specify this in a file named diskspace.cfg that is in the same folder as this script."
        exit
    fi
  done
}

function main {
  check_variables

  minute=0
  while [ 1 ]; do
    if [ $(( $minute % $MINUTE_FREQUENCY )) -eq 0 ]; then
      if [ "$EXCLUDE_LIST" != "" ] ; then
        df -PH | grep -vE "^Filesystem|tmpfs|cdrom|${EXCLUDE_LIST}" | check_disk_used
      else
        df -PH | grep -vE "^Filesystem|tmpfs|cdrom" | check_disk_used
      fi
    fi
    sleep 60
    minute=`expr $minute + 1`
  done
}

# Run the main script
main
