%pre --interpreter /bin/sh
exec < /dev/tty3 > /dev/tty3 2>&1
chvt 3
# Author: Ramesh Basukala <basukalarameshATgmailDOTcom>
# Purpose: to let user choose partition layout on kickstart
# Last Modified: 02.25.2014
defaultswapsize=4000

# Function to print partition layout
printPartition() {
   eval "declare -A parts="${1#*=}
   for p in "${!parts[@]}";
   do
      if [ "$p" == "root"  ] || [ "$p" == "/" ]; then
         partition_name_to_display="/"
         #echo "/ -  ${parts["$p"]}"
      elif [ "$p" == "swap" ]; then
         partition_name_to_display="swap"
      else
         partition_name_to_display="/$p"
         #echo "/$p -  ${parts["$p"]}"
      fi
      
      if [ "${parts["$p"]}" == 0 ]; then
         if [ $partition_name_to_display == "swap" ]; then
            partition_size_display=$defaultswapsize
         else
            partition_size_display="All remaining disk space"
         fi
      else
         partition_size_display=${parts["$p"]}
      fi
      echo "$partition_name_to_display -  $partition_size_display"
   done
}


# Function to generate partition lines
function partline() {
   if [ "$1" == "swap" ] ; then
      if [ "$2" == 0 ]; then
         swap_size=$defaultswapsize    
      else
         swap_size=$2
      fi
      echo "logvol swap --name=lv_swap --vgname=VolGroup00 --size=$swap_size"

   else
      if [ "$1" == "root" ] || [ "$1" == "/"  ] ; then
         part_name="root"
         part_mount="/"
      else
         part_mount="/$1"
         part_name="$1"
      fi
 
      if [ "$2" == 0 ] ; then
         echo "logvol $part_mount  --name=lv_$part_name --vgname=VolGroup00  --grow --size=1"
      else
         echo "logvol $part_mount --name=lv_$part_name --vgname=VolGroup00 --size=$2"
      fi
   fi
}


echo
echo "********************************************************************************"
echo "* W A R N I N G *"
echo "* *"
echo "*This process will wipe all your disks *"
echo "* *"
echo "********************************************************************************"
echo
echo
echo "!!!!! Partition named 'root' and '/' treated as same by this ks script !!!!!" 
echo
echo "To access redhat OS partitioning prompt: "
echo "    Press 'y' at 'Modify partition? (y|n)[N]: ' prompt"
echo "    At first prompt 'Partition name < Press ENTER to quit >:' press <ENTER> key, no value"
echo

declare -A partitions

partitions["var"]=10000
partitions["home"]=10000
partitions["swap"]=$defaultswapsize
partitions["root"]=0


echo "Default Layout: ";
echo "--------------  ";
printPartition "$(declare -p partitions)"

printf %s "Modify partition? (y|n)[N]: "
read choice

partition_modified_with_val=1

if [ "$choice" == "y" ] || [ "$choice" == "Y" ] ; then
   partition_modified_with_val=0
   partitions=(["swap"]=0)
   while :
   do
      printf %s "Partition name < Press ENTER (no value) to exit >: "
      read part_name

      if [ "$part_name" == "" ]; then
         break
      fi
      partition_modified_with_val=1
      # Allow users to enter partiotn name in "/<partition name>" or "<partition name>" format
      if [ "$part_name" != "/" ]; then
         initial_char="$(echo $part_name | head -c 1)"
         if [ "$initial_char" == "/" ]; then
            part_name=${part_name:1}
         fi
      fi

      printf %s "Size (MB) < Leave it blank or 0 to allocate ALL remaining space: "
      read part_size
         if [ -z "$part_size" ] ; then
            part_size="0"
         fi
      partitions["$part_name"]=$part_size
   done
fi

if [ "$partition_modified_with_val" != 0  ]; then
   cat <<EOF > /tmp/diskpart.cfg
clearpart --all
part /boot --size=500
part pv.008002 --grow --size=500
volgroup VolGroup00 pv.008002 --pesize=4096
EOF

   # Generate patitions line here
   for p in "${!partitions[@]}";
   do
      cat >> /tmp/diskpart.cfg  <<EOF
$(partline $p  ${partitions["$p"]})
EOF
   done

   echo "Partition layout after modification:";
   echo "----------------------------------- ";
   printPartition "$(declare -p partitions)"
else
   echo ' ' > /tmp/diskpart.cfg
fi

chvt 1
%end
