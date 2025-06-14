#!/usr/bin/env bash
#: Title       : vmnet-shark
#: Date        : 2015-09-30
#: Author      : Marc Weisel
#: Version     : 1.0
#: Description : Wireshark real-time packet capture and display for VMware Fusion vmnets

## Function definitions
usage()
{
  printf "USAGE: %s <vmnet>\n" $(basename $0)
}

# Give vmnet-sniffer tool the setuid (for root) attribute.
setuid_vmnet_sniffer() 
{
  if [ -e "$vmsniff" ]
  then
    if [ ! -u "$vmsniff" ]
    then
      /usr/bin/sudo /bin/chmod u+s "$vmsniff"
    fi
  else
    printf "ERROR: The vmnet-sniffer tool is not available.\n" >&2
    return 1
  fi
}

# Create fifo file for the vmnet.
create_vmnet_fifo() 
{
  if [ ! -p /private/tmp/$vmnet ]
  then
    /usr/bin/mkfifo /private/tmp/$vmnet
  fi
}

# Start the wireshark application using the vmnet fifo file as an "interface".
start_wireshark()
{
  if [ -e "$wspath" ]
  then
    "$wspath" -i /private/tmp/$vmnet -k &
  else
    printf "ERROR: Is Wireshark installed?\n" >&2
    return 1
  fi
}

# Start the vmnet-sniffer tool and have it write to the vmnet fifo file.
start_vmnet_sniffer()
{
  "$vmsniff" -w /private/tmp/$vmnet $vmnet &> /dev/null &
}

## File locations (default)
wspath='/Applications/Wireshark.app/Contents/MacOS/wireshark'
vmsniff='/Applications/VMware Fusion.app/Contents/Library/vmnet-sniffer'
vmnetpref='/Library/Preferences/VMware Fusion/networking'

# Is VMware Fusion running?
/usr/bin/pgrep vmware-vmx &> /dev/null
if [ $? -ne 0 ]
then
  printf "ERROR: Is the VMware Fusion application running?\n" >&2
  exit 1
fi

# Validate the vmnet parameter.
if [[ $# -eq 1 && $1 =~ ^vmnet[0-9]+$ ]]
then
  # Is the vmnet listed in the networking file?
  /usr/bin/grep -m 1 "_${1##*vmnet}_" "$vmnetpref" &> /dev/null
  if [ $? -eq 0 ]
  then
    # Are we already capturing on that vmnet?
    /usr/bin/pgrep -f tmp/$1 &> /dev/null
    if [ $? -ne 0 ]
    then
      vmnet=$1
      setuid_vmnet_sniffer && create_vmnet_fifo && start_wireshark
      if [ $? -eq 0 ]
      then
        start_vmnet_sniffer
      else
        exit 1
      fi
    else
      printf "ERROR: Wireshark is already capturing on $1\n" >&2
      exit 1
    fi
  else
    printf "ERROR: Has $1 been created?\n" >&2
    exit 1
  fi
else
  usage
  exit 1
fi

