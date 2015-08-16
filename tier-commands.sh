HOSTNAME=`hostname`

alias g=gluster

function tier_test {
    i=0
    while true; do
        echo $i
        ./run-tests.sh -f tests/basic/tier/tier.t;
        if [ $? != 0 ]; then
            break
        fi
        ((i=i+1))
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
    yes |gluster v attach-tier vol1 $HOSTNAME:/home/t3 $HOSTNAME:/home/t4 force
}

function tier_delete {
    yes|gluster v stop vol1;yes|gluster v delete vol1
}



