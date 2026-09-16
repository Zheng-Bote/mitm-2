#!/bin/bash
file=/home/zb_bamboo/Downloads/BMW/mitm_http-server/src/main.rs
# Replace ControlClient with AsyncControlClient in main.rs
sed -i 's/rpc::ControlClient,/rpc::{ControlClient, AsyncControlClient},/g' $file

# Replace let control = connect_control(...).await?;
cat << 'INNER_EOF' > replacement.txt
    let control = AsyncControlClient::new();
    let control_clone = control.clone();
    let control_socket = args.control_socket.clone();
    let enabled_repo = repo.clone();
    tokio::spawn(async move {
        loop {
            match ControlClient::connect(&control_socket, dispatcher.clone()).await {
                Ok(client) => {
                    tracing::info!("scheduler control socket connected");
                    *control_clone.inner.write().await = Some(client.clone());
                    if let Ok(enabled) = enabled_repo.get_enabled_programs().await {
                        let _ = client.call("replace_programs", serde_json::to_value(enabled).unwrap()).await;
                    }
                    // Wait until it drops or errors out, then loop again
                    // For now just wait and let the connection handler manage it.
                    // Actually, ControlClient doesn't have a wait_disconnect.
                    // We just break out or sleep. We'll just loop and ping.
                    loop {
                        tokio::time::sleep(Duration::from_secs(10)).await;
                        if client.call("ping", serde_json::Value::Null).await.is_err() {
                            *control_clone.inner.write().await = None;
                            break;
                        }
                    }
                }
                Err(error) => {
                    tracing::warn!(%error,"scheduler control socket unavailable; retrying");
                    tokio::time::sleep(Duration::from_secs(5)).await;
                }
            }
        }
    });
    // Remove the blocking enabled programs replacement
INNER_EOF

# Do a manual replacement of the block
