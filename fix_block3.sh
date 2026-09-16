#!/bin/bash
for dir in mitm_scheduler-server mitm_http-server; do
    file=/home/zb_bamboo/Downloads/BMW/$dir/src/rpc.rs
    cat << 'INNER_EOF' > patch.txt
        self.pending.lock().await.insert(key.clone(), tx);
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
            self.pending.lock().await.remove(&key);
            return Err(error.into());
        }
INNER_EOF
    sed -i '234,248c\
        self.pending.lock().await.insert(key.clone(), tx);\
        let bytes = serde_json::to_vec(\&RpcMessage::request(id, method, params))?;\
        let write_result = {\
            let mut output = self.write.lock().await;\
            let res = output.write_all(\&bytes).await;\
            if res.is_ok() {\
                output.write_all(b"\\n").await\
            } else {\
                res\
            }\
        };\
        if let Err(error) = write_result {\
            self.pending.lock().await.remove(\&key);\
            return Err(error.into());\
        }' $file
done
