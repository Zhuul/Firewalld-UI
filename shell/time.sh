echo "|-Checking if ntpdate command is ready.."
is_ntpdate=$(which ntpdate)
if [ "$is_ntpdate" = "" ];then
   if [ -f /usr/bin/apt ];then
       apt install ntpdate -y
   else
       is_dnf=$(which dnf)
       if [ "$is_dnf" = "" ];then
                yum install ntpdate -y
       fi
   fi
fi
is_ntpdate=$(which ntpdate)
is_http=0
if [ "$is_ntpdate" != "" ];then
    echo "|-Attempting to synchronize time..";
    ntpdate -u ntp.ntsc.ac.cn ntp.aliyun.com time.windows.com
else
    is_http=1
fi
echo "|-Attempting to write current system time to hardware..";
hwclock -w
echo "|-Current time is: $(date)"
echo "|-Time synchronization complete!";
