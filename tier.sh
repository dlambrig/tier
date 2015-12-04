MASTER=gprfs017
SLAVE=gprfs019
SLAVE2=
CLIENT=gprfs018
VOL=vol1
FREQ=60
SUBVOL=/home

function cleanup {
    for i in {0..12};do rm -rf /home/t$i;mkdir /home/t$i;done
}

function cleanup_slave {
    ssh $SLAVE 'for i in {0..12};do rm -rf /home/t$i;mkdir /home/t$i;done'
}

function cleanup_slave2 {
    ssh $SLAVE2 'for i in {0..12};do rm -rf /home/t$i;mkdir /home/t$i;done'
}

function buildfs {
    ssh $MASTER 'j=0;for i in {b..m};do echo 'making sd'$i;mkfs.xfs -f /dev/sd$i;mkdir -p $SUBVOL/t$j;mount /dev/sd$i $SUBVOL/t$j;(( j+= 1));done'
    ssh $SLAVE 'j=0;for i in {b..m};do echo 'making sd'$i;mkfs.xfs -f /dev/sd$i;mkdir -p $SUBVOL/t$j;mount /dev/sd$i $SUBVOL/t$j;(( j+= 1));done'
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
    gluster v create $VOL replica 2 $MASTER:$SUBVOL/t1 $MASTER:$SUBVOL/t2 $MASTER:$SUBVOL/t3 $MASTER:$SUBVOL/t4 $MASTER:$SUBVOL/t5 $MASTER:$SUBVOL/t6 force
    gluster v start $VOL
    preparms $VOL
    gluster volume set $VOL diagnostics.client-log-level DEBUG
}

function dist {
    dist_cold
    yes | gluster v attach-tier $VOL replica 2 $SLAVE:$SUBVOL/t0 $SLAVE:$SUBVOL/t1 $SLAVE:$SUBVOL/t2 $SLAVE:$SUBVOL/t3 force
    postparms $VOL
    ssh $CLIENT mount -t glusterfs $MASTER:/$VOL  /mnt
}

function dist_test {
    dist_cold
    ssh $CLIENT mount $MASTER:/$VOL  /mnt
    ssh $CLIENT mkdir -p /mnt/z/a
#    yes | gluster v stop $VOL
    yes | gluster v attach-tier $VOL replica 2 $SLAVE:$SUBVOL/t0 $SLAVE:$SUBVOL/t1 $SLAVE:$SUBVOL/t2 $SLAVE:$SUBVOL/t3 force
#    gluster v start $VOL
    postparms $VOL
}

function ec {
    gluster v create $VOL disperse 6 redundancy 2 $MASTER:$SUBVOL/t1 $SLAVE:$SUBVOL/t1 $MASTER:$SUBVOL/t2 $SLAVE:$SUBVOL/t2 $MASTER:$SUBVOL/t3 $SLAVE:$SUBVOL/t3 $MASTER:$SUBVOL/t4 $SLAVE:$SUBVOL/t4 $MASTER:$SUBVOL/t5 $SLAVE:$SUBVOL/t5 $MASTER:$SUBVOL/t6 $SLAVE:$SUBVOL/t6 force
    gluster v start $VOL
    preparms $VOL
    gluster volume set $VOL diagnostics.client-log-level TRACE
    yes | gluster v attach-tier $VOL replica 2 $MASTER:$SUBVOL/t7 $SLAVE:$SUBVOL/t7 $MASTER:$SUBVOL/8 $SLAVE:$SUBVOL/t9 force
    postparms $VOL
    ssh $CLIENT mount  $MASTER:/$VOL  /mnt
}

function dist_wm {
    for i in {1..4}; do
        ssh $SLAVE mkdir /mnt/fastbrick$i
        ssh $SLAVE dd if=/dev/zero of=/var/tmp/disk$i bs=1M count=2000
        ssh $SLAVE mkfs --type=xfs  /var/tmp/disk$i
        ssh $SLAVE mount /var/tmp/disk$i /mnt/fastbrick$i
    done
    dist_cold
    yes | gluster v attach-tier $VOL replica 2 $SLAVE:/mnt/fastbrick1 $SLAVE:/mnt/fastbrick2 $SLAVE:/mnt/fastbrick3 $SLAVE:/mnt/fastbrick4 force
    postparms $VOL
    ssh $CLIENT mount -t glusterfs $MASTER:/$VOL  /mnt
}

function die {
    killall glusterd
    killall glusterfs
    killall glusterfsd
    ssh $SLAVE killall glusterfs
    ssh $SLAVE killall glusterfsd
#    ssh $SLAVE2 killall glusterfs
#    ssh $SLAVE2 killall glusterfsd
    rm -rf /var/lib/glusterd
    ssh $SLAVE rm -rf /var/lib/glusterd
#    ssh $SLAVE2 rm -rf /var/lib/glusterd
    systemctl daemon-reload
    systemctl restart glusterd
    ssh $SLAVE systemctl daemon-reload
    ssh $SLAVE systemctl restart glusterd
    gluster peer probe $SLAVE
#    ssh $SLAVE2 systemctl daemon-reload
#    ssh $SLAVE2 systemctl restart glusterd
#    gluster peer probe $SLAVE2
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
    #    gluster v create $VOL disperse 6 redundancy 2 $MASTER:$SUBVOL/t0 $MASTER:$SUBVOL/t1 $SLAVE:$SUBVOL/t0 $SLAVE:$SUBVOL/t1 $SLAVE2:$SUBVOL/t0 $SLAVE2:$SUBVOL/t1 force
    gluster v create $VOL disperse 6 redundancy 2 $MASTER:$SUBVOL/t0 $MASTER:$SUBVOL/t1 $MASTER:$SUBVOL/t2 $SLAVE:$SUBVOL/t0 $SLAVE:$SUBVOL/t1 $SLAVE:$SUBVOL/t2 force
    gluster v start vol1 force
    preparms $VOL
    yes | gluster v attach-tier $VOL replica 2 $MASTER:$SUBVOL/t3 $SLAVE:$SUBVOL/t3 $MASTER:$SUBVOL/t4 $SLAVE:$SUBVOL/t4 $MASTER:$SUBVOL/t5 $SLAVE:$SUBVOL/t5 force
    postparms $VOL

    ssh $CLIENT mount -t glusterfs   $MASTER:/$VOL  /mnt

}

function perf2 {
#    gluster v create $VOL disperse 6 redundancy 2 $MASTER:$SUBVOL/t0 $MASTER:$SUBVOL/t1 $SLAVE:$SUBVOL/t0 $SLAVE:$SUBVOL/t1 $SLAVE2:$SUBVOL/t0 $SLAVE2:$SUBVOL/t1 force
    gluster v create $VOL disperse 6 redundancy 2 $MASTER:$SUBVOL/t0 $MASTER:$SUBVOL/t1 $MASTER:$SUBVOL/t2 $SLAVE:$SUBVOL/t3 $SLAVE:$SUBVOL/t4 $SLAVE:$SUBVOL/t5 force
    gluster v start vol1 force
    preparms $VOL
#    ssh $CLIENT mount  $MASTER:/$VOL  /mnt
    ssh $CLIENT mount -t glusterfs  $MASTER:/$VOL  /mnt

}

function perf3 {

    yes | gluster v create $VOL replica 2 $MASTER:$SUBVOL/t0 $MASTER:$SUBVOL/t1 $MASTER:$SUBVOL/t2 $SLAVE:$SUBVOL/t0 $SLAVE:$SUBVOL/t1 $SLAVE:$SUBVOL/t2 force
    gluster v start vol1 force
    preparms $VOL
    ssh $CLIENT mount  $MASTER:/$VOL  /mnt
}

function perf4 {
    #    gluster v create $VOL disperse 6 redundancy 2 $MASTER:$SUBVOL/t0 $MASTER:$SUBVOL/t1 $SLAVE:$SUBVOL/t0 $SLAVE:$SUBVOL/t1 $SLAVE2:$SUBVOL/t0 $SLAVE2:$SUBVOL/t1 force
    yes | gluster v create $VOL  replica 2 $MASTER:$SUBVOL/t0 $SLAVE:$SUBVOL/t0 $MASTER:$SUBVOL/t1 $SLAVE:$SUBVOL/t1 force
    #yes | gluster v create $VOL  replica 2 $MASTER:$SUBVOL/t0 $MASTER:$SUBVOL/t1 $MASTER:$SUBVOL/t2 $SLAVE:$SUBVOL/t0 force
#    gluster v set vol1 cluster.lookup-optimize on
    gluster v start vol1 force
    preparms $VOL
    yes | gluster v attach-tier $VOL replica 2 $MASTER:$SUBVOL/t2 $SLAVE:$SUBVOL/t2 $MASTER:$SUBVOL/t3 $SLAVE:$SUBVOL/t3 force
    #yes | gluster v attach-tier $VOL replica 2 $MASTER:$SUBVOL/t3 $SLAVE:$SUBVOL/t3 $MASTER:$SUBVOL/t4 $SLAVE:$SUBVOL/t4  force
    postparms $VOL

    ssh $CLIENT mount -t glusterfs   $MASTER:/$VOL  /mnt

}

function perf5 {
    gluster v create $VOL  replica 2 $MASTER:$SUBVOL/t0 $MASTER:$SUBVOL/t1 $MASTER:$SUBVOL/t2 $SLAVE:$SUBVOL/t0 $SLAVE:$SUBVOL/t1 $SLAVE:$SUBVOL/t2 $MASTER:$SUBVOL/t3 $SLAVE:$SUBVOL/t3 $MASTER:$SUBVOL/t4 $SLAVE:$SUBVOL/t4 $MASTER:$SUBVOL/t5 $SLAVE:$SUBVOL/t5 force
    gluster v start $VOL force
    preparms $VOL
    
    postparms $VOL

    ssh $CLIENT mount -t glusterfs   $MASTER:$VOL  /mnt

}

function perf6 {
    yes | gluster v create vol2  replica 2 $MASTER:$SUBVOL/t6 $MASTER:$SUBVOL/t7 $MASTER:$SUBVOL/t8 $SLAVE:$SUBVOL/t6 $SLAVE:$SUBVOL/t7 $SLAVE:$SUBVOL/t8 force
    gluster v start vol2 force
    preparms vol2
    yes | gluster v tier vol2 attach replica 2 $MASTER:$SUBVOL/t9 $SLAVE:$SUBVOL/t9 $MASTER:$SUBVOL/t10 $SLAVE:$SUBVOL/t10 $MASTER:$SUBVOL/t11 $SLAVE:$SUBVOL/t11 force
    postparms $VOL

    ssh $CLIENT mount -t glusterfs   $MASTER:/vol2  /mnt2

}

while getopts ":nsdceatbp" opt; do
    case $opt in
        c)
            echo build fs
            buildfs
            ;;
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
          sleep 20
          echo Waited $rand seconds
          yes | gluster v tier $VOL attach $SLAVE:$SUBVOL/t7 $SLAVE:$SUBVOL/t8 $SLAVE:$SUBVOL/t9 $SLAVE:$SUBVOL/t10 force
          s=$(date +%s)
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
#          ssh $SLAVE "cd $SUBVOL;while ! getfattr -e hex -m fix-layout-done -d t0|grep fix-layout-done ;do echo Wait for fix layout;sleep 3;done"

          ssh $CLIENT "while pgrep tar;do date +%s; echo waiting from $s for $(pgrep tar);sleep 2;done"
          ssh $CLIENT "cat /tmp/out"
          ssh $CLIENT "find /mnt/z|wc -l"
          echo Done. Now attach
          yes | gluster v attach-tier $VOL replica 2 $SLAVE:$SUBVOL/t0 $SLAVE:$SUBVOL/t1 $SLAVE:$SUBVOL/t2 $SLAVE:$SUBVOL/t3 force
          ;;
      p)
          shift $((OPTIND-1))
          getopts ":abcdef" opt
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
              d)
                  echo distrep+distrep tiered
                  perf4
                  ;;
              e) echo big distrep
                 perf5
                 ;;
              f) echo  distrep+distrep tiered t6-t12
                 perf6
                 ;;
          esac
          ;;
      \?)
          echo "-n : start from scratch: kill restart glusterd"
          echo "-s : stop and remove tiered volume"
          echo "-da : create tiered distributed volume"
          echo "-db : create 100M tiered distributed volume to test watermarks"
          echo "-e : create tiered ec volume"
          echo "-a : attach volume test (I/O durring attach)"
          echo "-b : attach volume test (no I/O during attach)"
          echo "-pa : performance test setup ec+distrep"
          echo "-pb : performance test setup ec"
          echo "-pc : performance test setup distrep"
          ;;
      esac
done


