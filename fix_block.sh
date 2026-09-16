#!/bin/bash
for dir in mitm_scheduler-server mitm_http-server; do
    file=/home/zb_bamboo/Downloads/BMW/$dir/src/rpc.rs
    cat << 'INNER_EOF' > patch.txt
        let bytes = serde_json::to_vec(&RpcMessage::request(id, method, params))?;
        let write_result = {
            let mut output = self.write.lock().await;
            let res = output.write_all(&bytes).await;
            if res.is_ok() {
                output.write_all(b"\n").await
            } else {
                res
            }
        };
        if let Err(error) = write_result {
INNER_EOF
    sed -i '236,244c\
        let bytes = serde_json::to_vec(&RpcMessage::request(id, method, params))?;\
        let write_result = {\
            let mut output = self.write.lock().await;\
            let res = output.write_all(\&bytes).await;\
            if res.is_ok() {\
                output.write_all(b"\\n").await\
            } else {\
                res\
            }\
        };\
        if let Err(error) = write_result {' $file
done
