#!/usr/bin/env bash
# $1/$2:    client/server directory paths
# $3/$4/$5: mss/window/parallelism parameters

server_dir=$1
client_dir=$2
server_results="$server_dir-results.csv"
client_results="$client_dir-results.csv"
mss_sizes=$3
window_sizes=$4
parallelisms=$5

get_test_parameters () {
    IFS=',' read -r -a mss_sizes <<< "$1"
    IFS=',' read -r -a window_sizes <<< "$2"
    IFS=',' read -r -a parallelisms <<< "$3"
}

# Save transfer and bitrate from a given result file
extract_data() {
    result_file=$1
    summary="$(cat $result_file | tail -n 4 | head -n 1)"

    # NOTE: if you use the -P flag, print 4 and 6 instead
    transfer="$(echo $summary | awk '{print $5}')"
    bitrate="$(echo $summary | awk '{print $7}')"

    # If there isn't anything in transfer/bitrate, the
    # file might be empty so the test needs to be rerun.
    if [[ -z $transfer ]] || [[ -z $bitrate ]]; then
        echo "$1 has blank fields - may need to rerun test."
    fi

    # Accounts for Transfer being in MBytes
    if [[ $(echo $summary | grep "MBytes") ]]; then
        transfer=$(echo $transfer | awk '{printf "%.3f", $1 / 1000}')
    fi
    # Accounts for Bitrate being in Mbit/s.
    if [[ $(echo $summary | grep "Mbits/sec") ]]; then
        bitrate=$(echo $bitrate | awk '{printf "%.3f", $1 / 1000}')
    fi

    total_transfer=$(echo $total_transfer $transfer \
            | awk '{printf "%.1f", $1 + $2}')
    total_bitrate=$(echo $total_bitrate $bitrate \
            | awk '{printf "%.1f", $1 + $2}')
}

# $1 is the directory containing data
# $2 is the results file to output to
create_csv () {
    for m in "${mss_sizes[@]}"
    do
        for w in "${window_sizes[@]}"
        do
            for p in "${parallelisms[@]}"
            do
                total_transfer=0
                total_bitrate=0
                for i in $(seq 1 $p);
                do
                    old_filename="$1/$m-$w-$p-part$i.txt"
                    vl100_data="$1/$m-$w-$p-part$i-1.txt"
                    vl200_data="$1/$m-$w-$p-part$i-2.txt"
                    [[ -f $old_filename ]] && extract_data $old_filename
                    [[ -f $vl100_data ]] && extract_data $vl100_data
                    [[ -f $vl200_data ]] && extract_data $vl200_data
                done
                echo "$m,$w,$p,$total_transfer,$total_bitrate" | tee -a $2
            done
        done
    done
}

# Creates an empty .csv with headers
# $1 is the path of the file to generate
generate_results_file () {
    rm $1 2>/dev/null && sudo touch $1
    echo "MSS,Window,Parallelism,Transfer(Gbytes),Bitrate(Gbits/sec)" | tee $1
}

# Extract parameters
get_test_parameters $3 $4 $5

# Generate server results
echo "=== Generating Server Results ==="
echo "Creating results file..."
generate_results_file $server_results
echo "Parsing data for results..."
create_csv $server_dir $server_results
echo "Done."

# Generate client results
echo "=== Generating Client Results ==="
echo "Creating results file..."
generate_results_file $client_results
echo "Parsing data for results..."
create_csv $client_dir $client_results
echo "Done."
