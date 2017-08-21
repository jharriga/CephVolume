# CephVolume
scripts to prepare LVM logical volumes and device partitions for use in ceph-volume
  * buildLVM.sh   <-- builds the configuration
  * destroyLVM.sh <-- teardown the configuration

```
Section from /usr/share/ceph-ansible/group_vars/osds
osd_scenario: lvm
lvm_volumes:
  cached-lv0: /dev/nvme0n1p5
  cached-lv1: /dev/nvme0n1p6
  cached-lv2: /dev/nvme0n1p7
  noncached-lv0: /dev/nvme0n1p8
  noncached-lv1: /dev/nvme0n1p9
  noncached-lv2: /dev/nvme0n1p10
NOTE: each of the lvm_volumes logvol names must be unique
```

=========================================================================================

```
buildLVM.sh
-----------------------
AFTER RUNNING lsblk output resembles:

nvme0n1                259:0    0 745.2G  0 disk 
├─nvme0n1p1            259:1    0    12G  0 part 
├─nvme0n1p2            259:2    0    12G  0 part 
├─nvme0n1p3            259:3    0    12G  0 part 
├─nvme0n1p4            259:4    0     1K  0 part 
├─nvme0n1p5            259:5    0     5G  0 part 
├─nvme0n1p6            259:6    0     5G  0 part 
├─nvme0n1p7            259:7    0     5G  0 part 
├─nvme0n1p8            259:8    0     5G  0 part 
├─nvme0n1p9            259:9    0     5G  0 part 
└─nvme0n1p10           259:10   0     5G  0 part 

sde                     8:64   0   1.8T  0 disk 
sdf                     8:80   0   1.8T  0 disk 
sdg                     8:96   0   1.8T  0 disk 

AFTER RUNNING lvs output resembles:
 LV            VG            Attr       LSize   Pool              Origin             Data%  Meta%  Move Log Cpy%Sync Convert
 home          rhel_gprfs041 -wi-ao---- 382.80g
 root          rhel_gprfs041 -wi-ao----  50.00g 
 swap          rhel_gprfs041 -wi-ao---- <31.44g    

 cached-lv0    cached-vg0    Cwi-a-C--- 100.00g [lv_cached_data0] [cached-lv0_corig] 0.01   0.14            0.00            
 cached-lv1    cached-vg1    Cwi-a-C--- 100.00g [lv_cached_data1] [cached-lv1_corig] 0.01   0.14            0.00            
 cached-lv2    cached-vg2    Cwi-a-C--- 100.00g [lv_cached_data2] [cached-lv2_corig] 0.01   0.14            0.00            
 noncached-lv0 noncached-vg0 -wi-a----- 100.00g     
 noncached-lv1 noncached-vg1 -wi-a----- 100.00g     
 noncached-lv2 noncached-vg2 -wi-a----- 100.00g  
```
