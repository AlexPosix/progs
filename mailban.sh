#!/bin/sh                                                                                            
#----------------------------------------------------------------------------------------------------
#       Copyright by Vaskovskij 2014 																 
#----------------------------------------------------------------------------------------------------
# This script parse postfix's log file and drop users who try to make unauthorized attempts to login.
# Run it using cron and forget about brootforcers.  



cat /var/log/mail.log | grep '[0-9\{1,3\}\.[0-9]\{1,3\}\.[0-9\{1,3\}\.[0-9]\{1,3\}]' | grep -E 'authentication failed' | awk '{print $7}' | sed -n 's/\[/ /p' | sed -n 's/\]\:/ /p' | awk '{print $2}' | while read ip
do
echo $ip >> ./ip
done
uniq -c ./ip | while read count ip
do
	if [ $count -gt 10 ]
		then
		var=`/sbin/iptables --list -n | awk {'print $4'} | grep $ip | sort -u`
			if [ "$var" = "$ip" ]
				then
				:
#echo $var
				else
				/sbin/iptables -A INPUT -s $ip -j DROP
			fi
	fi
done
rm ./ip


cat /var/log/mail.log | grep '[0-9\{1,3\}\.[0-9]\{1,3\}\.[0-9\{1,3\}\.[0-9]\{1,3\}]' | grep -E 'LOGIN FAILED' | awk '{print substr($9,12)}' | sed -n 's/\]/ /p' | while read ip
do
echo $ip >> ./ip
done
uniq -c ./ip | while read count ip
do
	if [ $count -gt 10 ]
		then
		var=`/sbin/iptables --list -n | awk {'print $4'} | grep $ip | sort -u`
			if [ "$var" = "$ip" ]
			then
			:
#echo $var
			else
			/sbin/iptables -A INPUT -s $ip -j DROP
			fi
	fi
done
rm ./ip

