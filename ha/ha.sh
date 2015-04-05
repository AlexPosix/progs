#!/bin/sh
#----------------------------------------------------------
#       Copyright by Vaskovskij 2014 (v 1.0)              |
#----------------------------------------------------------
#This script allows to migrate ip address from master node to slave and back by checking availabity using ping and response http state.      
#It have to start on slave node. Before start this script we need to copy configuration file ha.conf to /etc/ha.conf. Also we have to 
#generate public key on slave node by ssh-keygen and add contents of this file onto /.ssh/authorized_keys master's node, its necessary 
#for manipulate commands on master node. For sending mail we need to use sendEmail script in /etc/scripts/sendEmail folder (we may 
#download it follow the link http://caspian.dotconf.net/menu/Software/SendEmail/). Also we need curl (apt-get install curl).                          
#



log_file=/var/log/ha.log
conf=/etc/ha.conf
machine="`uname -n`"
. $conf

general ()
{
 while true
    do
        if ! /bin/ping -c $counts_of_icmp $master_ip >> /dev/null
            then
            echo "master host is unreachable" >> $log_file
            echo `date` >> $log_file
            /etc/scripts/sendEmail -f $from_email -u $subject_message_fail_node -m $message_fail_node -t $to_email -s $smtp_server >> $log_file
            /sbin/ifconfig $interface:0 up $ip_alias/$network > /dev/null >> $log_file
            while true
                do
                    if  !/bin/ping -c $counts_of_icmp $master_ip >> /dev/null
                        then
                        :
                        else
                        echo `date` >> $log_file
                        /etc/scripts/sendEmail -f $from_email -u $subject_message_node_up -m $message_node_up -t $to_email -s $smtp_server >> $log_file
                        echo "host is up" >> $log_file
                        /sbin/ifconfig $interface:0 down >> $log_file
                        break
                    fi
                sleep $time_after_ping
            done
        else
        :
        fi
        sleep $time_after_ping
    done
}

http ()
{
while true
    do
    status=`timeout -s 9 $response_time curl -o /dev/null --silent --head --write-out '%{http_code}\n' -H "Host: $http_host" $http_scheme://$master_ip` >> /dev/null
#sleep $periodic
        if [ "$status" != "$http_response" ]
            then
            echo "master host is unreachable, http checker" >> $log_file
            echo `date` >> $log_file
            /etc/scripts/sendEmail -f $from_email -u $subject_message_fail_node -m $message_fail_node -t $to_email -s $smtp_server >> $log_file
            ssh root@$master_ip "/sbin/ifconfig $interface_master:0 down" >> $log_file
            /sbin/ifconfig $interface:0 up $ip_alias/$network > /dev/null >> $log_file
            while true
                do
                status=`curl -o /dev/null --silent --head --write-out '%{http_code}\n' -H "Host: $http_host" $http_scheme://$master_ip` >> /dev/null
                if [ "$status" != "$http_response" ]
                    then
                    :
                    else
                    echo `date` >> $log_file
                    /etc/scripts/sendEmail -f $from_email -u $subject_message_node_up -m $message_node_up -t $to_email -s $smtp_server >> $log_file
                    echo "host is up" >> $log_file
                    /sbin/ifconfig $interface:0 down >> $log_file
                    ssh root@$master_ip "/sbin/ifconfig $interface_master:0 up $ip_alias/$network"  >> $log_file
                    break
                fi
                 sleep $periodic
                 done
            else
            :
        fi
        sleep $periodic
    done
}

case "$1" in

start)
if ls /var/run | grep ha.pid 1>/dev/null
	then
	echo "ha already running"
	exit 1
fi

if  [ "$ping_check" = "on" ]
    then
    general &
    pid1=$!
fi

if  [ "$http_status" = "on" ]
    then
    http &
    pid=$!
fi

echo "-----------------------------ha start----------------------------" | tee -a $log_file
echo `date` >> $log_file
echo "starting ha ( pid=$pid )" | tee -a $log_file
echo $pid $pid1 > /var/run/ha.pid
ssh root@$master_ip "/sbin/ifconfig $interface_master:0 up $ip_alias/$network"  >> $log_file
;;
stop)
if ! ls /var/run | grep ha.pid 1>/dev/null
    then
    echo "ha is not running"
    exit 1
fi
string=`cat /var/run/ha.pid` 2>/dev/null
kill -9 $string 1>/dev/null
rm /var/run/ha.pid >/dev/null 2>&1
while ps aux | awk '{print $11}' | grep "sleep\>" 1>/dev/null
    do
    echo "ha stopping" | tee -a $log_file
    killall sleep >/dev/null 2>&1
    sleep 1
    done
eth=`ifconfig | awk '{print $1}' | grep "0:0\>"`
if [ "$eth" = "$interface:0" ]
    then
    /sbin/ifconfig $interface:0 down
fi
echo "ha was stopped" | tee -a $log_file
echo "------------------------------ha stop-----------------------------" | tee -a $log_file
echo `date` >> $log_file
;;
*)
echo "Usage: `basename $0` {start|stop}"
exit 1
;;
esac

