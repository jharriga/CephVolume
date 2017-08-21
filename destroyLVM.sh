#-------------------------------------
# destroyLVM.sh
# Tears-down the NONcached and LVMcached lvm configurations
#

#-----------------------------------
# FUNCTIONS

function updatelog {
# Echoes passed string to LOGFILE and stdout
    echo `$DATE`": $1" 2>&1 | tee -a $LOGFILE
}

function error_exit {
# Function for exit due to fatal program error
# Accepts 1 argument:
#   string containing descriptive error message
    echo "${PROGNAME}: ${1:-"Unknown Error"} ABORTING..." 1>&2
    exit 1
}

#----------------------------------
# VARIABLES
DATE='date +%Y/%m/%d:%H:%M:%S'
ts="$(date +%Y%m%d-%H%M%S)"
LOGFILE="./destroyLVM_$ts.log"

# Number of LVMcached and NONcached lv's to destroy
numdevs=3

# NONcached device vars
noncachedDEV_arr=( "/dev/sde" "/dev/sdf" "/dev/sdg" )
noncachedVG="noncached-vg"
noncachedLV="noncached-lv"

# LVMcached SLOW device vars
slowDEV_arr=( "/dev/sdh" "/dev/sdi" "/dev/sdj" )

# LVMcached FAST device vars
fastDEV="nvme0n1"
fastTARGET="/dev/${fastDEV}"
fastDEV_arr=( "${fastTARGET}p1" "${fastTARGET}p2" "${fastTARGET}p3" )

# LVMcached lvm vars
cachedVG="cached-vg"
cachedLV="cached-lv"

#------------------------------------------------

#################################################

updatelog "destroyLVM.sh begin"

#------------------------------------------------
updatelog "Destroying  NONcached devices"

# FOR Loop - remove the number of specified NONcached devices
#   Operations: lvremove, vgremove, pvremove
for (( cntr=0; cntr < $numdevs; cntr++ )); do
  # Assign vars for this loop
  dev="${noncachedDEV_arr[$cntr]}"
  vg="${noncachedVG}$cntr"
  lv="${noncachedLV}$cntr"

  # If mounted then EXIT
  mount | grep ${dev}
  if [ $? == 0 ]; then
    echo "Device ${dev} is mounted - ABORTING"
    exit 1
  fi

  # Remove the NONcached LV
  lvpath="/dev/${vg}/${lv}"
  lvremove --force ${lvpath} || \
    error_exit "$LINENO: Unable to lvremove ${lvpath}"
  updatelog "lvremove of ${lvpath} complete"

  # Remove the VG
  vgremove --force ${vg} || \
    error_exit "$LINENO: Unable to vgremove ${vg}"
  updatelog "vgremove of ${vg} complete"

  # Remove the PVs
  pvremove --force --yes ${dev} || \
    error_exit "$LINENO: Unable to pvremove ${dev}"
  updatelog "pvremove of ${dev} complete"
done       # end FOR

#------------------------------------------------
updatelog "Destroying  LVMcached devices"

# FOR Loop - remove the number of specified LVMcached devices
#   Operations: lvremove, vgremove, pvremove
for (( cntr=0; cntr < $numdevs; cntr++ )); do
  # Assign vars for this loop
  slowdev="${slowDEV_arr[$cntr]}"
  fastdev="${fastDEV_arr[$cntr]}"
  vg="${cachedVG}$cntr"
  lv="${cachedLV}$cntr"

  # If mounted then EXIT
  mount | grep ${slowdev}
  if [ $? == 0 ]; then
    echo "Device ${slowDEV} is mounted - ABORTING"
    exit 1
  fi
  mount | grep ${fastDEV}
  if [ $? == 0 ]; then
    echo "Device ${fastDEV} is mounted - ABORTING"
    exit 1
  fi

  # Remove the cached LV
  lvpath="/dev/${vg}/${lv}"
  lvremove --force ${lvpath} || \
    error_exit "$LINENO: Unable to lvremove ${lvpath}"
  updatelog "lvremove of ${lvpath} complete"

  # Remove the VG
  vgremove --force ${vg} || \
    error_exit "$LINENO: Unable to vgremove ${vg}"
  updatelog "vgremove of ${vg} complete"

  # Remove the PVs
  pvremove --force --yes ${fastdev} || \
    error_exit "$LINENO: Unable to pvremove ${fastdev}"
  updatelog "pvremove of ${fastdev} complete"
  pvremove --force --yes ${slowdev} || \
    error_exit "$LINENO: Unable to pvremove ${slowdev}"
  updatelog "pvremove of ${slowdev} complete"
done       # end FOR

# Delete paritioning from the fastDEV
updatelog "Removing partitions from ${fastTARGET}"
parted -s $fastTARGET mktable gpt
partprobe $fastTARGET
lsblk | tee -a $LOGFILE

updatelog "destroyLVM.sh done"
#
# END destroyLVM.sh
