HOSTNAME=`hostname`
function db {
    printf "Flink tb\n\n"
    echo "select * from gf_flink_tb;" | sqlite3 $1
    printf "\nFile tb\n\n"
    echo "select * from gf_file_tb;" | sqlite3 $1
}

function tier_create {
    gluster v create vol1 $HOSTNAME:/home/t1 $HOSTNAME:/home/t2 force
    gluster v start vol1
    yes |gluster v attach-tier vol1 $HOSTNAME:/home/t3 $HOSTNAME:/home/t4 force
}

function tier_delete {
    yes|gluster v stop vol1;yes|gluster v delete vol1
}



