#!/bin/sh

echo "" > /tmp/smarterroremail

CURRENTDOMAIN=$ENV

BLACKSMITH_DIR=/usr/local/blacksmith
HBASE_DIR=$BLACKSMITH_DIR/hbase
HADOOP_DIR=$BLACKSMITH_DIR/hadoop

HBASE_BIN=$HBASE_DIR/bin
HADOOP_BIN=$HADOOP_DIR/bin

HBASE_DAEMON=$HBASE_BIN/hbase-daemon.sh
HADOOP_DAEMON=$HADOOP_BIN/hadoop-daemon.sh
HBASE_GRACEFULSTOP=$HBASE_BIN/graceful_stop.sh

if [ -a "$HBASE_DIR/hbase-flurry-regionserver.pid" ]
then
REGIONSERVER_PID=`cat $HBASE_DIR/hbase-flurry-regionserver.pid`
        echo "regionserver pid exists"
else
REGIONSERVER_PID="null_0"
        echo "regionserver pid does not exist"
fi

if [ -a "$HADOOP_DIR/hadoop-flurry-datanode.pid" ]
then
DATANODE_PID=`cat $HADOOP_DIR/hadoop-flurry-datanode.pid`
        echo "datanode pid exists"
else
DATANODE_PID="null_0"
        echo "datanode pid does not exist"
fi

if [ -a "$HADOOP_DIR/hadoop-flurry-tasktracker.pid" ]
then
TASKTRACKER_PID=`cat $HADOOP_DIR/hadoop-flurry-tasktracker.pid`
        echo "tasktracker pid exists"
else
TASKTRACKER_PID="null_0"
        echo "tasktracker pid does not exist"
fi




HOSTNAME=`hostname`
HOSTDOMAIN=`hostname -f`

echo "==================== WARNING ====================" >> /tmp/smarterroremail
echo "Problem detected with disk: $SMARTD_DEVICESTRING" >> /tmp/smarterroremail
echo "Warning message from smartd is: $SMARTD_MESSAGE" >> /tmp/smarterroremail
echo "" >> /tmp/smarterroremail

#CHECK IF ZOOKEEPER
ZKLIST=`curl -s http://hmaster1.$CURRENTDOMAIN:60010/master-status | grep Zookeeper | cut -d '>' -f5 | cut -d '<' -f1 | cut -d '.' -f1,4,7 | sed 's/.com:2181,/ /g'`
#echo $ZKLIST >> /tmp/smarterroremail
#echo $HOSTNAME >> /tmp/smarterroremail
for ZKNODE in `echo $ZKLIST`
do
# echo $ZKNODE >> /tmp/smarterroremail
        if [ $HOSTNAME == $ZKNODE ]
        then
echo "This is a Zookeeper, please manually shut this server down." >> /tmp/smarterroremail
                mail -s "CRITICAL ZOOKEEPER -- $HOSTDOMAIN:$SMARTD_DEVICE $SMARTD_FAILTYPE, SMART ERROR" $SMARTD_ADDRESS < /tmp/smarterroremail
                exit 0
        else
echo "This is not a Zookeeper node $ZKNODE, proceed"
        fi
done



echo "This is not a Zookeeper node, proceed" >> /tmp/smarterroremail

#CHECK NODES SHUTDOWN

BASERSCOUNT=`curl -s http://mgr1.$CURRENTDOMAIN/regionserverbase`
BASETTCOUNT=`curl -s http://mgr1.$CURRENTDOMAIN/tasktrackerbase`
BASEDNCOUNT-`curl -s http://mgr1.$CURRENTDOMAIN/datanodebase`

CURRENTRSCOUNT=`curl -s http://hmaster1.$CURRENTDOMAIN:60010/master-status | grep Total | grep requests | cut -d ':' -f3 | cut -d '<' -f1`
CURRENTTTCOUNT=`curl -s http://hmaster1.$CURRENTDOMAIN:50030/jobtracker.jsp | grep machines | cut -d '>' -f10 | cut -d '<' -f1`
CURRENTDNCOUNT=`curl -s http://hmaster1.$CURRENTDOMAIN:50070/dfsnodelist.jsp?whatNodes=LIVE | grep Live | cut -d ':' -f2 | cut -d '<' -f1`

RSDIFF=$(($BASERSCOUNT-$CURRENTRSCOUNT))
#RSDIFF=2


if [ $RSDIFF -gt 1 ]
then
echo "Since there have been multiple Regionserver service shutdowns, please manually shut this server down." >> /tmp/smarterroremail
        mail -s "CRITICAL -- $HOSTDOMAIN:$SMARTD_DEVICE $SMARTD_FAILTYPE, SMART ERROR" $SMARTD_ADDRESS < /tmp/smarterroremail
        exit 0
else

        #echo "Number of acceptable regionservers running verified" >> /tmp/smarterroremail
        echo "" >> /tmp/smarterroremail
fi

TTDIFF=$(($BASETTCOUNT-$CURRENTTTCOUNT))
#TTDIFF=2


if [ $TTDIFF -gt 1 ]
then
echo "Since there have been multiple TaskTracker service shutdowns, please manually shut this server down." >> /tmp/smarterroremail
        mail -s "CRITICAL -- $HOSTDOMAIN:$SMARTD_DEVICE $SMARTD_FAILTYPE, SMART ERROR" $SMARTD_ADDRESS < /tmp/smarterroremail
        exit 0
else

        #echo "Number of nodes removed from hadoop and hbase cluster are less than one, proceed" >> /tmp/smarterroremail
        echo "" >> /tmp/smarterroremail
fi


DNDIFF=$(($BASEDNCOUNT-$CURRENTDNCOUNT))
#DNDIFF=2


if [ $DNDIFF -gt 1 ]
then
echo "Since there have been multiple DataNode service shutdowns, please manually shut this server down." >> /tmp/smarterroremail
        mail -s "CRITICAL -- $HOSTDOMAIN:$SMARTD_DEVICE $SMARTD_FAILTYPE, SMART ERROR" $SMARTD_ADDRESS < /tmp/smarterroremail
        exit 0
else

        #echo "Number of nodes removed from hadoop and hbase cluster are less than one, proceed" >> /tmp/smarterroremail
        echo "" >> /tmp/smarterroremail
fi


#echo "Stopping hadoop and hbase services" >> /tmp/smarterroremail

#STOP REGIONSERVER
echo "==================== STOPPING REGIONSERVER ====================" >> /tmp/smarterroremail
echo "Gracefully removing regions from bad hslave"
echo $HBASE_GRACEFULSTOP $HOSTNAME
$HBASE_GRACEFULSTOP $HOSTNAME
echo Running $HBASE_DAEMON stop regionserver >> /tmp/smarterroremail
su - flurry -c "$HBASE_DAEMON stop regionserver" &
#echo $HBASE_GRACEFULSTOP $HOSTNAME
#Verify and pause 60 seconds if not shutdown
for (( counter = 0; counter <= 3; counter++ ))
do
if [ "`ps ax | grep java | grep -v grep | grep $REGIONSERVER_PID`" > /dev/null ]
        then
if [ $counter -eq 3 ]
                then
echo "Force killing Regionserver" >> /tmp/smarterroremail
                        kill -9 $REGIONSERVER_PID
                        #kill -9 $REGIONSERVER_PID
                        sleep 60
                else
echo "Waiting 60 seconds for Regionserver to stop" >> /tmp/smarterroremail
                        sleep 60
                fi
else
echo "Regionserver is stopped" >> /tmp/smarterroremail
                counter=4
        fi
done
echo "" >> /tmp/smarterroremail

#STOP TASKTRACKER
echo "==================== STOPPING TASKTRACKER ====================" >> /tmp/smarterroremail
echo Running $HADOOP_DAEMON stop tasktracker >> /tmp/smarterroremail
su - flurry -c "$HADOOP_DAEMON stop tasktracker" &

#Verify and pause 60 seconds if not shutdown
for (( counter = 0; counter <= 3; counter++ ))
do
if [ "`ps ax | grep java | grep -v grep | grep $TASKTRACKER_PID`" > /dev/null ]
        then
if [ $counter -eq 3 ]
                then
kill -9 $TASKTRACKER_PID
                        echo "Force killing Tasktracker" >> /tmp/smarterroremail
                        sleep 60
                else
echo "Waiting 60 seconds for Tasktracker to stop" >> /tmp/smarterroremail
                        sleep 60
                fi
else
echo "Tasktracker is stopped" >> /tmp/smarterroremail
                counter=4
        fi
done
echo "" >> /tmp/smarterroremail

#STOP DATANODE
echo "==================== STOPPING DATANODE ====================" >> /tmp/smarterroremail
echo Running $HADOOP_DAEMON stop datanode >> /tmp/smarterroremail
su - flurry -c "$HADOOP_DAEMON stop datanode" &

#Verify and pause 60 seconds if not shutdown
for (( counter = 0; counter <= 3; counter++ ))
do
if [ "`ps ax | grep java | grep -v grep | grep $DATANODE_PID`" > /dev/null ]
        then
if [ $counter -eq 3 ]
                then
echo "Force killing Datanode" >> /tmp/smarterroremail
                        kill -9 $DATANODE_PID
                        sleep 60
                else
echo "Waiting 60 seconds for Datanode to stop" >> /tmp/smarterroremail
                        sleep 60
                fi
else
echo "Datanode is stopped" >> /tmp/smarterroremail
                counter=4
        fi
done

mail -s "$HOSTDOMAIN:$SMARTD_DEVICE $SMARTD_FAILTYPE, SMART ERROR" $SMARTD_ADDRESS < /tmp/smarterroremail
