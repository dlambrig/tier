HOSTNAME=`hostname`
FREQ=60

alias g=gluster

function tier_test {
    while true; do
        ./run-tests.sh -f tests/basic/tier/tier.t;
        if [ $? != 0 ]; then
            break
        fi
    done
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
    yes |gluster v tier vol1 attach $HOSTNAME:/home/t3 $HOSTNAME:/home/t4 force
}

function tier_delete {
    yes|gluster v stop vol1;yes|gluster v delete vol1
}

function postparms {
    gluster v set $1 features.ctr-enabled on
    gluster volume set $1 cluster.read-freq-threshold 0
    gluster volume set $1 cluster.write-freq-threshold 0
    gluster volume set $1 cluster.tier-demote-frequency $FREQ
    gluster volume set $1 cluster.tier-promote-frequency $FREQ
    gluster volume set $1 diagnostics.client-log-level DEBUG
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
