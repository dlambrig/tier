
function db {
    printf "Flink tb\n\n"
    echo "select * from gf_flink_tb;" | sqlite3 $1
    printf "\nFile tb\n\n"
    echo "select * from gf_file_tb;" | sqlite3 $1
}

function tier_create {
    gluster v create vol1 rhs-cli-14:/home/t1 rhs-cli-14:/home/t2 force
    gluster v start vol1
    yes |gluster v attach-tier vol1 rhs-cli-14:/home/t3 rhs-cli-14:/home/t4 force
}

function tier_delete {
    yes|gluster v stop vol1;yes|gluster v delete vol1
}



