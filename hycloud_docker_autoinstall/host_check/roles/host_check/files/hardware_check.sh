#!/bin/bash

self_ip=$1
target_cpu_cores=$2
target_mem_size=$3
target_disk_size=$4
target_io_speed=$5
target_folder_path=${6-/TRS}


output_file="${self_ip//./_}_hardware_check_result.log"
rm -f  ${output_file}

current_cpu_cores=$(cat /proc/cpuinfo|grep processor|wc -l)
current_mem_size=$(export LC_ALL='en_US.UTF-8';free -m|grep 'Mem:'|awk '{print $2}')


server_state='服务器检测正常'
output_result=''

if [[ ${current_cpu_cores} -lt ${target_cpu_cores} ]]
then
  server_state='服务器检测异常'
  output_result="${output_result} MinCPUCore:${target_cpu_cores}:${current_cpu_cores}:CPU当前${current_cpu_cores},不满足最低${target_cpu_cores}:bad"
else
  output_result="${output_result} MinCPUCore:${target_cpu_cores}:${current_cpu_cores}:CPU当前${current_cpu_cores},满足最低${target_cpu_cores}:good"
fi



if [[ ${current_mem_size} -lt ${target_mem_size} ]]
then
  server_state='服务器检测异常'
  output_result="${output_result} MinMemSize:${target_mem_size}:${current_mem_size}:内存当前${current_mem_size}MB，不满足最低${target_mem_size}MB:bad"
else 
  output_result="${output_result} MinMemSize:${target_mem_size}:${current_mem_size}:内存当前${current_mem_size}MB，满足最低${target_mem_size}MB:good"
fi

if [ -d ${target_folder_path} ]
then
   current_disk_size=$(stat ${target_folder_path} >/dev/null 2>&1 && df -BG ${target_folder_path}|tail -n 1|awk '{print $4}'|sed  -e 's/G//g')
   raw_io_speed_info=$(exec 2>&1;export LC_ALL='en_US.UTF-8';echo 3 | sudo tee /proc/sys/vm/drop_caches;dd if=/dev/zero  of=${target_folder_path}/testIO.tmp  bs=1M  count=500 iflag=fullblock)
   
   tmp_io_speed_value=$(echo "${raw_io_speed_info}"|tail -n 1|awk '{print $8}')
   tmp_io_speed_unit=$(echo "${raw_io_speed_info}"|tail -n 1|awk '{print $9}')
   
   
   if [[ ${tmp_io_speed_unit} =~ GB.* ]]
   then
      tmp_io_speed_value=$(awk "BEGIN {print ${tmp_io_speed_value} * 1000}")
   elif [[ ${tmp_io_speed_unit} =~ KB.* ]]
   then
      tmp_io_speed_value=$(awk "BEGIN {print ${tmp_io_speed_value} / 1000}")
   elif [[ ${tmp_io_speed_unit} =~ MB.* ]]
   then
      tmp_io_speed_value=$(awk "BEGIN {print ${tmp_io_speed_value} * 1}")
   fi
   
   if [[ ${current_disk_size} -lt ${target_disk_size} ]]
   then
     server_state='服务器检测异常'
     output_result="${output_result} MinDiskSize:${target_disk_size}:${current_disk_size}:${target_folder_path}目录当前${current_disk_size}GB，不满足最低${target_disk_size}GB:bad"
   else
     output_result="${output_result} MinDiskSize:${target_disk_size}:${current_disk_size}:${target_folder_path}目录当前${current_disk_size}GB，满足最低${target_disk_size}GB:good"
   fi
   
   
   if  [ $(echo "${tmp_io_speed_value} < ${target_io_speed}"| bc) -eq 1 ] 
   then
     server_state='服务器检测异常'
     output_result="${output_result} MinDiskIOSpeed:${target_io_speed}:${tmp_io_speed_value}:${target_folder_path}目录当前IO速度${tmp_io_speed_value}MB/s，不满足最低${target_io_speed}MB/s:bad"
   else
     output_result="${output_result} MinDiskIOSpeed:${target_io_speed}:${tmp_io_speed_value}:${target_folder_path}目录当前IO速度${tmp_io_speed_value}MB/s，满足最低${target_io_speed}MB/s:good"
   fi
else
     server_state='服务器检测异常'
     output_result="${output_result} MinDiskSize:${target_disk_size}:-1:${target_folder_path}不存在，无法进行磁盘空间检测:bad"

     server_state='服务器检测异常'
     output_result="${output_result} MinDiskIOSpeed:${target_io_speed}:-1:${target_folder_path}不存在，无法进行磁盘IO检测:bad"
fi     


if [ ! -d ${target_folder_path} ]
then
  server_state='服务器检测异常'
  output_result="${output_result} FolderMustExist:${target_folder_path}目录需存在:${target_folder_path}不存在:目标目录${target_folder_path}不存在:bad"
else
  output_result="${output_result} FolderMustExist:${target_folder_path}目录需存在:${target_folder_path}已存在:目标目录${target_folder_path}已存在:good"
fi

### add at 20201030  新增目录权限检测
if [ ! -d ${target_folder_path} ]
then
  server_state='服务器检测异常'
  output_result="${output_result} FolderMustOwnByRoot:${target_folder_path}目录需ROOT权限:${target_folder_path}不存在:目标目录${target_folder_path}不存在,无法进行权限检测:bad"
else
  tmp_owner=$(stat -c '%U' /TRS)
  if  [[ "${tmp_owner}" == 'root' ]]
  then
     output_result="${output_result} FolderMustOwnByRoot:${target_folder_path}必须属于ROOT用户:正常:${target_folder_path}已经属于ROOT用户:good"
  else
     server_state='服务器检测异常'
	 output_result="${output_result} FolderMustOwnByRoot:${target_folder_path}必须属于ROOT用户:异常:${target_folder_path}属于${tmp_owner}用户:bad"
  fi
fi




#####    end    ####
output_result="summary:${server_state} ${output_result}"

echo "${output_result}">${output_file}
