MASTER=rhs-cli-01
SLAVE=rhs-cli-02
SLAVE2=rhs-cli-01
CLIENT=rhs-cli-11
VOL=vol1
FREQ=60

function cleanup {
    for i in {0..10};do rm -rf /home/t$i;mkdir /home/t$i;done
}

function cleanup_slave {
    ssh $SLAVE 'for i in {0..10};do rm -rf /home/t$i;mkdir /home/t$i;done'
}

function cleanup_slave2 {
    ssh $SLAVE2 'for i in {0..10};do rm -rf /home/t$i;mkdir /home/t$i;done'
}

function postparms {
    gluster v set $1 features.ctr-enabled on
    gluster volume set $1 cluster.read-freq-threshold 0
    gluster volume set $1 cluster.write-freq-threshold 0
    gluster volume set $1 cluster.tier-demote-frequency $FREQ
    gluster volume set $1 cluster.tier-promote-frequency $FREQ
    gluster volume set $1 diagnostics.client-log-level DEBUG
}

function preparms {
    gluster v set $1 performance.quick-read off
    gluster v set $1 performance.io-cache off
}

function dist_cold {
    gluster v create $VOL replica 2 $MASTER:/home/t1 $MASTER:/home/t2 $MASTER:/home/t3 $MASTER:/home/t4 $MASTER:/home/t5 $MASTER:/home/t6 force
    gluster v start $VOL
    preparms $VOL
    gluster volume set $VOL diagnostics.client-log-level DEBUG
}

function dist {
    dist_cold
    yes | gluster v attach-tier $VOL replica 2 $SLAVE:/home/t0 $SLAVE:/home/t1 $SLAVE:/home/t2 $SLAVE:/home/t3 force
    postparms $VOL
    ssh $CLIENT mount -t glusterfs $MASTER:/$VOL  /mnt
}

function dist_test {
    dist_cold
    ssh $CLIENT mount $MASTER:/$VOL  /mnt
    ssh $CLIENT mkdir -p /mnt/z/a
#    yes | gluster v stop $VOL
    yes | gluster v attach-tier $VOL replica 2 $SLAVE:/home/t0 $SLAVE:/home/t1 $SLAVE:/home/t2 $SLAVE:/home/t3 force
#    gluster v start $VOL
    postparms $VOL
}

function ec {
    gluster v create $VOL disperse 6 redundancy 2 $MASTER:/home/t1 $MASTER:/home/t2 $MASTER:/home/t3 $MASTER:/home/t4 $MASTER:/home/t5 $MASTER:/home/t6 force
    gluster v start $VOL
    preparms $VOL
    gluster volume set $VOL diagnostics.client-log-level TRACE
    yes | gluster v attach-tier $VOL replica 2 $SLAVE:/home/t0 $SLAVE:/home/t1 $SLAVE:/home/t2 $SLAVE:/home/t3 force
    postparms $VOL
    ssh $CLIENT mount  $MASTER:/$VOL  /mnt
}

function dist_wm {
    for i in {1..4}; do
        ssh $SLAVE mkdir /mnt/fastbrick$i
        ssh $SLAVE dd if=/dev/zero of=/var/tmp/disk$i bs=1M count=100
        ssh $SLAVE mkfs --type=xfs  /var/tmp/disk$i
        ssh $SLAVE mount /var/tmp/disk$i /mnt/fastbrick$i
    done
    dist_cold
    yes | gluster v attach-tier $VOL replica 2 $SLAVE:/mnt/fastbrick1 $SLAVE:/mnt/fastbrick2 $SLAVE:/mnt/fastbrick3 $SLAVE:/mnt/fastbrick4 force
    postparms $VOL
    ssh $CLIENT mount -t glusterfs $MASTER:/$VOL  /mnt
}

function die {
    killall glusterfs
    killall glusterfsd
    ssh $SLAVE killall glusterfs
    ssh $SLAVE killall glusterfsd
    ssh $SLAVE2 killall glusterfs
    ssh $SLAVE2 killall glusterfsd
    rm -rf /var/lib/glusterd
    ssh $SLAVE rm -rf /var/lib/glusterd
    ssh $SLAVE2 rm -rf /var/lib/glusterd
    systemctl daemon-reload
    systemctl restart glusterd
    ssh $SLAVE systemctl daemon-reload
    ssh $SLAVE systemctl restart glusterd
    gluster peer probe $SLAVE
    ssh $SLAVE2 systemctl daemon-reload
    ssh $SLAVE2 systemctl restart glusterd
    gluster peer probe $SLAVE2
    gluster peer status
}

function stop {
    yes | gluster v stop $VOL force
    yes | gluster v delete $VOL
    cleanup
    cleanup_slave
    cleanup_slave2
    for i in {1..4}; do
        ssh $SLAVE umount /mnt/fastbrick$i
    done
    ssh $CLIENT umount -f /mnt
}

function setup  {
    ssh-copy-id $CLIENT
    ssh-copy-id $SLAVE
    ssh-copy-id $SLAVE2
}

function perf1 {
    gluster v create $VOL disperse 6 redundancy 2 $MASTER:/home/t0 $MASTER:/home/t1 $SLAVE:/home/t0 $SLAVE:/home/t1 $SLAVE2:/home/t0 $SLAVE2:/home/t1 force
    gluster v start vol1 force
    preparms $VOL
    yes | gluster v attach-tier $VOL replica 2 $MASTER:/home/t2 $MASTER:/home/t3 $SLAVE:/home/t2 $SLAVE:/home/t3 $SLAVE2:/home/t2 $SLAVE2:/home/t3 force
    postparms $VOL

    ssh $CLIENT mount  $MASTER:/$VOL  /mnt

}

function perf2 {
    gluster v create $VOL disperse 6 redundancy 2 $MASTER:/home/t0 $MASTER:/home/t1 $SLAVE:/home/t0 $SLAVE:/home/t1 $SLAVE2:/home/t0 $SLAVE2:/home/t1 force
    gluster v start vol1 force
    preparms $VOL
    ssh $CLIENT mount  $MASTER:/$VOL  /mnt
}

function perf3 {

    yes | gluster v create $VOL replica 2 $MASTER:/home/t2 $MASTER:/home/t3 $SLAVE:/home/t2 $SLAVE:/home/t3 $SLAVE2:/home/t2 $SLAVE2:/home/t3 force
    gluster v start vol1 force
    preparms $VOL
    ssh $CLIENT mount  $MASTER:/$VOL  /mnt
}

while getopts ":nsdeatbp" opt; do
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
          shift $((OPTIND-1))
          getopts ":abc" opt
          case $opt in
              a)
                  echo dist
                  dist
                  ;;
              b)
                  echo dist_wm
                  dist_wm
                  ;;
          esac
          ;;
      t)  
          echo dist_test
          dist_test
          ;;
      e) 
          echo setup ec volume
          ec
          ;;
      a)
          echo attach tier test
          dist_cold
          rand=$(( ( RANDOM % 10 )  + 1 ))

          postparms $VOL
#          ssh $CLIENT mount  $MASTER:/$VOL  /mnt
          ssh $CLIENT mount  -t glusterfs $MASTER:/$VOL  /mnt
          ssh $CLIENT mkdir /mnt/z
          ssh -f $CLIENT "cd /mnt/z;tar xf /root/g.tar 2> /tmp/out;echo $? >> /tmp/out"
          sleep $rand
          echo Waited $rand seconds
          yes | gluster v attach-tier $VOL replica 2 $SLAVE:/home/t7 $SLAVE:/home/t8 $SLAVE:/home/t9 $SLAVE:/home/t10 force
          s=$(date +%s)
#          ssh $SLAVE "cd /home;while ! getfattr -e hex -m fix-layout-done -d t0|grep fix-layout-done ;do echo Wait for fix layout;sleep 3;done"

          ssh $CLIENT "while pgrep tar;do date +%s; echo waiting from $s for $(pgrep tar);sleep 2;done"
          ssh $CLIENT "cat /tmp/out"
          ssh $CLIENT "find /mnt/z|wc -l"
          echo Done
          ;;
      b)
          echo easier attach tier test
          dist_cold
          rand=$(( ( RANDOM % 10 )  + 1 ))

          postparms $VOL
          ssh $CLIENT mount  $MASTER:/$VOL  /mnt
#          ssh $CLIENT mount  -t glusterfs $MASTER:/$VOL  /mnt
          ssh $CLIENT mkdir /mnt/z
          ssh -f $CLIENT "cd /mnt/z;tar xf /root/g.tar 2> /tmp/out;echo $? >> /tmp/out"
#          sleep $rand
#          echo Waited $rand seconds
          s=$(date +%s)
#          ssh $SLAVE "cd /home;while ! getfattr -e hex -m fix-layout-done -d t0|grep fix-layout-done ;do echo Wait for fix layout;sleep 3;done"

          ssh $CLIENT "while pgrep tar;do date +%s; echo waiting from $s for $(pgrep tar);sleep 2;done"
          ssh $CLIENT "cat /tmp/out"
          ssh $CLIENT "find /mnt/z|wc -l"
          echo Done. Now attach
          yes | gluster v attach-tier $VOL replica 2 $SLAVE:/home/t0 $SLAVE:/home/t1 $SLAVE:/home/t2 $SLAVE:/home/t3 force
          ;;
      p)
          shift $((OPTIND-1))
          getopts ":abc" opt
          case $opt in
              a)
                  echo ec+distrep tiered
                  perf1
                  ;;
              b)
                  echo just ec
                  perf2
                  ;;
              c)
                  echo just dist
                  perf3
                  ;;
              esac
          ;;
      \?)
          echo "-n : start from scratch: kill restart glusterd"
          echo "-s : stop and remove tiered volume"
          echo "-d : create tiered distributed volume"
          echo "-e : create tiered ec volume"
          echo "-a : attach volume test (I/O durring attach)"
          echo "-b : attach volume test (no I/O during attach)"
          echo "-p : performance test setup"
          ;;
      esac
done


