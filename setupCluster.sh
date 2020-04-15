#! /bin/bash

rm -f $HOME/hostfile
echo "start nfs server"
sudo service nfs-kernel-server start

myIP=`curl http://169.254.169.254/latest/meta-data/local-ipv4`
slots=36 # c5n.18xlarge has 36 cores. This number has to be changed, if another instance type is used.

cat $HOME/allIPs | while read IP ; do
    echo "$IP slots=$slots" >>$HOME/hostfile
    echo "myIP:    >$myIP<"
    echo "otherIP: >$IP<"
    if [ "x$IP" == "x$myIP" ]; then
        echo "do not connect to myself: $myIP $IP"
        continue
    fi

    echo "connect >$IP< nfs to >$myIP<"
    ssh $IP "sudo mount $myIP:${HOME}/OpenFOAM ${HOME}/OpenFOAM" < /dev/null
done