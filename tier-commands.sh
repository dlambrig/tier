HOSTNAME=`hostname`
FREQ=60

alias g=gluster
alias fsd="./fs-drift.py -t /mnt/fst -d 60 -f 500 -s 256 -r 64 -D 10 -l 2 -i 1 --random-distribution gaussian --mean-velocity 1 --gaussian-stddev 40 --create_stddevs-ahead 10 --short-stats 1"

function tier_test {
    while true; do
        ./run-tests.sh -f tests/basic/tier/tier.t;
        if [ $? != 0 ]; then
            break
        fi
    done
}

function postparms {
    gluster v set $1 features.ctr-enabled on
    gluster volume set $1 cluster.read-freq-threshold 0
    gluster volume set $1 cluster.write-freq-threshold 0
    gluster volume set $1 cluster.tier-demote-frequency $FREQ
    gluster volume set $1 cluster.tier-promote-frequency $FREQ
    gluster volume set $1 diagnostics.client-log-level DEBUG
}

function tier_wm {
    dd if=/dev/zero of=/var/tmp/disk1 bs=1M count=100
    dd if=/dev/zero of=/var/tmp/disk2 bs=1M count=100
    mkfs --type=xfs  /var/tmp/disk1
    mkfs --type=xfs  /var/tmp/disk2
    mount /var/tmp/disk1 /mnt/fastbrick1
    mount /var/tmp/disk2 /mnt/fastbrick2
    gluster v create vol1 $HOSTNAME:/home/t1 $HOSTNAME:/home/t2 force
    gluster v set vol1 diagnostics.client-log-level DEBUG
    gluster v start vol1
    yes |gluster v attach-tier vol1 replica 2 $HOSTNAME:/mnt/fastbrick1 $HOSTNAME:/mnt/fastbrick2 force
    mount -t glusterfs $HOSTNAME:/vol1 /mnt/wm
    postparms vol1
}

function tier_d_wm {
    umount -f /mnt/wm
    rm -f /mnt/wm
    mkdir /mnt/wm
    yes | gluster v stop vol1
    yes | gluster v delete vol1
    umount /mnt/fastbrick1
    umount /mnt/fastbrick2
}

function db {
    printf "Flink tb\n\n"
    echo "select * from gf_flink_tb;" | sqlite3 $1
    printf "\nFile tb\n\n"
    echo "select * from gf_file_tb;" | sqlite3 $1
}

function tier_create {
    gluster v create vol1 $HOSTNAME:/home/t1 $HOSTNAME:/home/t2 force
    gluster v set vol1 diagnostics.client-log-level DEBUG
    gluster v start vol1
    yes |gluster v attach-tier vol1  $HOSTNAME:/home/t3 $HOSTNAME:/home/t4 force
}

function tier_delete {
    yes|gluster v stop vol1;yes|gluster v delete vol1
}

function make_fs {
    for i in {1..4};do mkdir /mnt/t$i;done
    for i in {1..4};do dd if=/dev/zero of=/var/tmp/disk-image$i bs=1M count=20;done
    for i in {1..4};do mkfs -t xfs -q /var/tmp/disk-image$i;done
    for i in {1..4};do mount /var/tmp/disk-image$i /mnt/t$i;done
    gluster v create vol1 $HOSTNAME:/mnt/t1 $HOSTNAME:/mnt/t2 force
    yes | gluster v attach-tier vol1 $HOSTNAME:/mnt/t3 $HOSTNAME:/mnt/t4 force
    gluster v start vol1
    postparms vol1
}

function kill_fs {
    tier_delete
    for i in {1..4};do umount /var/tmp/disk-image$i ;done
    rm -f /var/tmp/dist-image*
}

# echo "DELETE FROM GF_FILE_TB WHERE GF_ID='e77d3873-b514-48ab-9477-a90ca019f864';"|sqlite3 /d/backends/patchy0/.glusterfs/patchy0.db

function db_fill {
    parent=$1

    for i in {1..$2}; do
        gfid=`uuidgen`
        $fname=data1
        $pathfname="/d/"$fname$i
        echo "insert into gf_file_tb (GF_ID, W_SEC, W_MSEC, UW_SEC, UW_MSEC) VALUES ("$gfid",1,2,3,4);" | sqlite3 /d/backends/patchy0/.glusterfs/patchy0.db
        echo "insert into gf_file_link_tb (GF_ID, GF_PID, FNAME, FPATH, W_DEL_FLAG, LINK_UPDATE) VALUES ("$gfid","$parent","$fname","$pathfname",0,0)"
    done
}
