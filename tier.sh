MASTER=rhs-cli-02
SLAVE=rhs-cli-01
CLIENT=rhs-cli-14

function cleanup {
    for i in {0..8};do rm -rf /home/t$i;mkdir /home/t$i;done
}

function cleanup_slave {
    ssh $SLAVE 'for i in {0..8};do rm -rf /home/t$i;mkdir /home/t$i;done'
}

function postparms {
    gluster v set $1 features.ctr-enabled on
    gluster volume set $1 cluster.read-freq-threshold 0
    gluster volume set $1 cluster.write-freq-threshold 0
    gluster volume set $1 cluster.tier-demote-frequency 60
    gluster volume set $1 cluster.tier-promote-frequency 60
}
function preparms {
    gluster v set $1 performance.quick-read off
    gluster v set $1 performance.io-cache off
}

function dist {
    gluster v create t replica 2 $MASTER:/home/t1 $MASTER:/home/t2 $MASTER:/home/t3 $MASTER:/home/t4 $MASTER:/home/t5 $MASTER:/home/t6 force
    gluster v start t
    preparms t
    gluster volume set t diagnostics.client-log-level DEBUG
    ssh $SLAVE /root/mem.sh
    yes | gluster v attach-tier t replica 2 $SLAVE:/home/t0 $SLAVE:/home/t1 $SLAVE:/home/t2 $SLAVE:/home/t3 force
    postparms t
    ssh $CLIENT mount  $MASTER:/t  /mnt
}

function ec {
    gluster v create t disperse 6 redundancy 2 $MASTER:/home/t1 $MASTER:/home/t2 $MASTER:/home/t3 $MASTER:/home/t4 $MASTER:/home/t5 $MASTER:/home/t6 force
    gluster v start t
    preparms t
    gluster volume set t diagnostics.client-log-level TRACE
    ssh $SLAVE /root/mem.sh
    yes | gluster v attach-tier t replica 2 $SLAVE:/home/t0 $SLAVE:/home/t1 $SLAVE:/home/t2 $SLAVE:/home/t3 force
    postparms t
    ssh $CLIENT mount  $MASTER:/t  /mnt
}

function die {
    killall glusterfs
    killall glusterfsd
    ssh $SLAVE killall glusterfs
    ssh $SLAVE killall glusterfsd
    rm -rf /var/lib/glusterd
    ssh $SLAVE rm -rf /var/lib/glusterd
    systemctl daemon-reload
    systemctl restart glusterd
    ssh $SLAVE systemctl daemon-reload
    ssh $SLAVE systemctl restart glusterd
    gluster peer probe $SLAVE
    gluster peer status
}

function stop {
    yes | gluster v stop t force
    yes | gluster v delete t 
    cleanup
    cleanup_slave
#    ssh $SLAVE /root/mem-clear.sh
    ssh $CLIENT umount -f /mnt
}

function setup  {
    ssh-copy-id $CLIENT
    ssh-copy-id $SLAVE
}

while getopts ":nsde" opt; do
  case $opt in
      n)
          echo copy client id
          setup
          echo restart glusterd and probe 
          die
          ;;
      s)
          echo stop
          stop
          ;;
      d)  
          echo dist
          dist
          ;;
      e) 
          echo setup ec volume
          ec
          ;;
      \?)
          echo "-n : start from scratch: kill restart glusterd"
          echo "-s : stop and remove tiered volume"
          echo "-d : create tiered distributed volume"
          echo "-e : create tiered ec volume"
          ;;
      esac
done

gluster v info
