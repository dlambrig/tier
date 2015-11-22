#!/bin/bash

. $(dirname $0)/../../include.rc
. $(dirname $0)/../../volume.rc
. $(dirname $0)/../../tier.rc


NUM_BRICKS=0
DEMOTE_FREQ=5
PROMOTE_FREQ=5

TEST_STR="Testing write and truncate fops on tier migration"


# Creates a tiered volume with pure distribute hot and cold tiers
# Both hot and cold tiers will have an equal number of bricks.

function create_dist_tier_vol () {
        mkdir $B0/cold
        mkdir $B0/hot
        TEST $CLI volume create $V0 $H0:$B0/cold/${V0}{0..$1}
        TEST $CLI volume set $V0 performance.quick-read off
        TEST $CLI volume set $V0 performance.io-cache off
        TEST $CLI volume set $V0 features.ctr-enabled on
        TEST $CLI volume start $V0
        TEST $CLI volume attach-tier $V0 $H0:$B0/hot/${V0}{0..$1}
        TEST $CLI volume set $V0 cluster.tier-demote-frequency $DEMOTE_FREQ
        TEST $CLI volume set $V0 cluster.tier-promote-frequency $PROMOTE_FREQ
        TEST $CLI volume set $V0 cluster.read-freq-threshold 0
        TEST $CLI volume set $V0 cluster.write-freq-threshold 0
}

# This function works with 64 bit Linux machines only.
# 1. read first subvolume, by passing in a small buffer size.
# 2. wait for file to be demoted.
# 3. read another buffer size.

function test_readdir () {
    case $OSTYPE in
        NetBSD | FreeBSD | Darwin)
        echo "1"
        return
        ;;
    esac

    if [ `arch` == "i686" ]; then
        echo "1"
    else
        ./readdir $M0 144 10 > /tmp/out
        if grep -q $1 /tmp/out; then
            echo "1"
        else
            echo "0"
        fi
    fi
}

cleanup;

#Basic checks
TEST glusterd
TEST pidof glusterd
TEST $CLI volume info


#Create and start a tiered volume
create_dist_tier_vol $NUM_BRICKS

# Mount FUSE
TEST glusterfs -s $H0 --volfile-id $V0 $M0

build_tester $(dirname $0)/readdir.c -o readdir

sleep_until_mid_cycle $DEMOTE_FREQ

touch $M0/FILE1

EXPECT "1" test_readdir FILE1

umount $M0

TEST glusterfs --use-readdir=false -s $H0 --volfile-id $V0 $M0
TEST ! $?

TEST $CLI volume set $V0 performance.force-readdirp false

sleep_until_mid_cycle $DEMOTE_FREQ

touch $M0/FILE2

EXPECT "1" test_readdir FILE2

cleanup;

