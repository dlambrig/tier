
function db {
    printf "Flink tb\n\n"
    echo "select * from gf_flink_tb;" | sqlite3 $1
    printf "\nFile tb\n\n"
    echo "select * from gf_file_tb;" | sqlite3 $1
}

