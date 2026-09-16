#!/bin/bash
for dir in mitm_scheduler-server mitm_http-server; do
    file=/home/zb_bamboo/Downloads/BMW/$dir/src/rpc.rs
    # Remove the first line (the use statement I added)
    sed -i '1d' $file
    # Add it after the doc comments
    sed -i '/^use std/i use std::sync::atomic::Ordering;' $file
    
    # Fix the async await
    sed -i 's/\.and_then(|_| output\.write_all(b"\\n")\.await)/; if write_result.is_ok() { write_result = output.write_all(b"\\n").await; }/' $file
done
