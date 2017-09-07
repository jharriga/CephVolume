#
# buildONLYLVS.sh
#-----------------------
# AFTER RUNNING lsblk output resembles:
#
# nvme0n1                259:0    0 745.2G  0 disk 
# ├─nvme0n1p1            259:1    0    12G  0 part 
# ├─nvme0n1p2            259:2    0    12G  0 part 
# ├─nvme0n1p3            259:3    0    12G  0 part 
# ├─nvme0n1p4            259:4    0     1K  0 part 
# ├─nvme0n1p5            259:5    0     5G  0 part 
# ├─nvme0n1p6            259:6    0     5G  0 part 
# ├─nvme0n1p7            259:7    0     5G  0 part 
# ├─nvme0n1p8            259:8    0     5G  0 part 
# ├─nvme0n1p9            259:9    0     5G  0 part 
# └─nvme0n1p10           259:10   0     5G  0 part 
# 
# sde                     8:64   0   1.8T  0 disk 
# sdf                     8:80   0   1.8T  0 disk 
# sdg                     8:96   0   1.8T  0 disk 
#
# AFTER RUNNING lvs output resembles:
#  LV            VG            Attr       LSize   Pool              Origin             Data%  Meta%  Move Log Cpy%Sync Convert
#  home          rhel_gprfs041 -wi-ao---- 382.80g
#  root          rhel_gprfs041 -wi-ao----  50.00g 
#  swap          rhel_gprfs041 -wi-ao---- <31.44g    
#
#  cached-lv0    cached-vg0    Cwi-a-C--- 100.00g [lv_cached_data0] [cached-lv0_corig] 0.01   0.14            0.00            
#  cached-lv1    cached-vg1    Cwi-a-C--- 100.00g [lv_cached_data1] [cached-lv1_corig] 0.01   0.14            0.00            
#  cached-lv2    cached-vg2    Cwi-a-C--- 100.00g [lv_cached_data2] [cached-lv2_corig] 0.01   0.14            0.00            
#  noncached-lv0 noncached-vg0 -wi-a----- 100.00g     
#  noncached-lv1 noncached-vg1 -wi-a----- 100.00g     
#  noncached-lv2 noncached-vg2 -wi-a----- 100.00g  
#
###############################################################

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
LOGFILE="./buildLVM_$ts.log"

# Number of LVMcached and NONcached lv's to create
numdevs=3

# NONcached device vars
noncachedDEV_arr=( "/dev/sde" "/dev/sdf" "/dev/sdg" )
noncachedVG="noncached-vg"
noncachedLV="noncached-lv"

# SLOW device vars
slowDEV_arr=( "/dev/sdh" "/dev/sdi" "/dev/sdj" )
#slowVG="slow-vg"
#slowLV="slow-lv"

# FAST device vars
fastDEV="nvme0n1"
fastTARGET="/dev/${fastDEV}"
fastDEV_arr=( "${fastTARGET}p1" "${fastTARGET}p2" "${fastTARGET}p3" )
#fastVG="fast-vg"
#fastLV="fast-lv"

# LVMcached device vars
cachedataLV="lv_cached_data"
cachemetaLV="lv_cached_meta"
cachedLV="cached-lv"
originLV="${cachedLV}"
cachedVG="cached-vg" 
cachePOLICY="smq"
cacheMODE="writethrough"

# Calculate the SIZEs, all based on unitSZ and cache_size values
# cache_size sets the LVMcache_data size
unitSZ="G"
let cache_size=10

# Size of the Cache
#  sets fastDEV size for lvcreate in Utils/setupLVM.shinc
#  sets LVMcache_data size for lvconvert in Utils/setupCACHE.shinc
cacheSZ="$cache_size$unitSZ"

# Calculate percentages used to roundup/down sizes
ten_percent=$(($cache_size / 10))
twenty_percent=$(($ten_percent * 2))
# Remember - bash only supports integer arithmetic
# exit if the roundups are not integers
if [ $ten_percent -lt 1 ]; then
  echo "Math error in vars.shinc - var 'ten_percent' must be integer >= 1"
  exit 1
fi

# Size of the fastDEV used by lvcreate 
#   roundup by 20%
fast_calc=$(($cache_size + $twenty_percent))
fastSZ="$fast_calc$unitSZ"
#
# Size of the slowDEV used by lvcreate
#   ten times size of cache
slow_calc=$(($cache_size * 10))
slowSZ="$slow_calc$unitSZ"

# LVMcache_metadata size is one tenth size of LVMcache_data
#   used by lvconvert in Utils/setupCACHE.shinc
metadata_calc=$(($cache_size / 10))
metadataSZ="$metadata_calc$unitSZ"
#
# Size of the origin lvm device used by lvcreate
originSZ="${slowSZ}"

#
#################################################################
#----------------------------------
# PARTITION the NVME
echo "Partitioning $fastTARGET"
echo "BEGIN: Listing matching device names"
# List the available block devices
lsblk | grep $fastDEV | tee -a $LOGFILE

# Create the partitions programatically (rather than manually)
# The sed script strips off all the comments so that we can 
# document what we're doing in-line with the actual commands
# Note that a blank line (commented as "default" will send a empty
# line terminated with a newline to take the fdisk default.
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk ${fastTARGET}
  o       # clear the in memory partition table
  n       # new partition
  p       # primary partition
  1       # partition number 1
          # default, start at beginning of disk 
  +12G   # 12 GB partition
  n       # new partition
  p       # primary partition
  2       # partition number 2
          # default, start immediately after preceding partition
  +12G   # 12 GB partition
  n       # new partition
  p       # primary partition
  3       # partition number 3
          # default, start immediately after preceeding partition
  +12G   # 12 GB partition
  n       # new partition
  e       # extended partition
  4       # partition number 4 : extended partition
          # default, start immediately after preceeding partition
  +50G    # 50 GB partition (to house remaining three partitions)
  n       # new partition 'p5'
          # default, start immediately after preceeding partition
  +5G    # 5 GB partition 
  n       # new partition 'p6'
          # default, start immediately after preceeding partition
  +5G    # 5 GB partition 
  n       # new partition 'p7'
          # default, start immediately after preceeding partition
  +5G    # 5 GB partition 
  n       # new partition 'p8'
          # default, start immediately after preceeding partition
  +5G    # 5 GB partition 
  n       # new partition 'p9'
          # default, start immediately after preceeding partition
  +5G    # 5 GB partition 
  n       # new partition 'p10'
          # default, start immediately after preceeding partition
  +5G    # 5 GB partition 
  p       # print the in-memory partition table
  w       # write the partition table
  q       # and we're done
EOF

echo "COMPLETED partitioning $fastDEV" | tee -a $LOGFILE
lsblk | grep $fastDEV | tee -a $LOGFILE

#----------------------------------
# Now work the LVMcached slowDEVs and NONcached HDDs
# Delete any existing partitions
#
hdd_arr+=( "${slowDEV_arr[@]}" "${noncachedDEV_arr[@]}" )
for hdd in "${hdd_arr[@]}"; do
  echo "Partitioning $hdd" | tee -a $LOGFILE
  echo "Checking if ${hdd} is in use, if yes abort"
  mount | grep ${hdd}
  if [ $? == 0 ]; then
    echo "Device ${hdd} is mounted - ABORTING Test!"
    exit 1
  fi

# Clears any existing partition table and creates a new one
#   with a single partion that is the entire disk
    (echo o; echo n; echo p; echo 1; echo; echo; echo w) | \
      fdisk ${hdd} >> $LOGFILE
# Now delete that partition
  for partition in $(parted -s ${hdd} print|awk '/^ / {print $1}'); do
    echo "Removing parition: dev=${hdd} - partition=${partition}"
    parted -s $hdd rm ${partition}
    if [ $? != 0 ]; then
      echo "$LINENO: Unable to remove ${partition} from ${hdd}"
      exit 1
    fi
  done
  echo "COMPLETED removed any partitions from: $hdd" | tee -a $LOGFILE
done

echo "COMPLETED partitioning all devices" | tee -a $LOGFILE

###################################################################
# Build the LOGICAL VOLUMES
#--------------------------
#
# NOTE that originLV = cachedLV
#

echo "Creating NONcached logical volumes"
# FOR Loop - create the number of specified NONcached logvols
for (( cntr=0; cntr < $numdevs; cntr++ )); do
  # assign vars for this loop
  dev="${noncachedDEV_arr[$cntr]}"
  vg="${noncachedVG}$cntr"
  lv="${noncachedLV}$cntr"

  # Step 1: create single Volume Group with NONcached device
#  pvcreate --yes ${dev} || \
#    error_exit "$LINENO: Unable to pvcreate ${dev}."
#  updatelog "pvcreate of ${dev} complete"
#  vgcreate --yes ${vg} ${dev} || \
#    error_exit "$LINENO: Unable to vgcreate ${vg}."
#  updatelog "vgcreate of ${vg} complete"
#
  # Step 2: create NONcached LV
  yes | lvcreate -L ${originSZ} -n ${lv} ${vg} || \
    error_exit "$LINENO: Unable to lvcreate ${lv}."
  updatelog "lvcreate of ${lv} complete"
done

echo "Creating LVMcached logical volumes"
# FOR Loop - create the number of specified LVMcached devices
for (( cntr=0; cntr < $numdevs; cntr++ )); do
  # assign vars for this loop
  slowdev="${slowDEV_arr[$cntr]}"
  fastdev="${fastDEV_arr[$cntr]}"
  vg="${cachedVG}$cntr"
  originlv="${originLV}$cntr"
  cachedatalv="${cachedataLV}$cntr"
  cachemetalv="${cachemetaLV}$cntr"

  # Step 1: create single Volume Group from two devices (fast and slow)
#  pvcreate --yes ${slowdev} || \
#    error_exit "$LINENO: Unable to pvcreate ${slowdev}."
#  updatelog "pvcreate of ${slowdev} complete"
#  pvcreate --yes ${fastdev} || \
#    error_exit "$LINENO: Unable to pvcreate ${fastdev}."
#  updatelog "pvcreate of ${fastdev} complete"
#  vgcreate --yes ${vg} ${slowdev} ${fastdev} || \
#    error_exit "$LINENO: Unable to vgcreate ${vg}."
#  updatelog "vgcreate of ${vg} complete"

  # Step 2: create origin LV
  yes | lvcreate -L ${originSZ} -n ${originlv} ${vg} ${slowdev} || \
    error_exit "$LINENO: Unable to lvcreate ${originlv}."
  updatelog "lvcreate of ${originlv} complete"

  # Step 3: create cache data LV
  yes | lvcreate -L ${cacheSZ} -n ${cachedatalv} ${vg} ${fastdev} || \
    error_exit "$LINENO: Unable to lvcreate ${cachedatalv}."
  updatelog "lvcreate of ${cachedatalv} complete"

  # Step 4: create cache metadata LV
  yes | lvcreate -L ${metadataSZ} -n ${cachemetalv} ${vg} ${fastdev} || \
    error_exit "$LINENO: Unable to lvcreate ${cachemetalv}."
  updatelog "lvcreate of ${cachemetalv} complete"

  # Step 5: create cache pool LV
  # Built from cache data and cache metadata LVs
  # NOTE that originLV = cachedLV (as set in vars.shinc)
  meta="${vg}/${cachemetalv}"
  cache="${vg}/${cachedatalv}"
  origin="${vg}/${originlv}"
  lvconvert --yes --force --type cache-pool --cachemode ${cacheMODE} \
    --poolmetadata ${meta} ${cache} || \
    error_exit "$LINENO: Unable to lvconvert ${cache}."
  updatelog "lvconvert of ${cache} complete"

  # Step 6: create cachedLV by combining cache pool and origin LVs
  # NOTE that originLV = cachedLV
  lvconvert --yes --force --type cache --cachepool ${cache} ${origin} || \
    error_exit "$LINENO: Unable to lvconvert ${origin}."
  updatelog "lvconvert of ${origin} complete"

  cachedlvpath="/dev/${vg}/${originlv}"
  updatelog "cachedLV ${cachedlvpath} created"

  # Step7: list LVMcache settings
  lvs -o+cache_mode ${origin} 2>&1 | tee -a $LOGFILE
  lvs -o+chunksize ${origin} 2>&1 | tee -a $LOGFILE
  lvs -o+cache_policy,cache_settings ${origin} 2>&1 | tee -a $LOGFILE

done         # end FOR LOOP

# List block device cfg
lsblk | tee -a $LOGFILE

# List LVM devices
lvs -a -o +devices 2>&1 | tee -a $LOGFILE

# List lvm config
lvdisplay | tee -a $LOGFILE

updatelog "buildLVM.sh done"
#
# END buildONLYLVS.sh
