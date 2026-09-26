import re

with open('core-layer/mitm_http-server/src/handlers/admin.rs', 'r') as f:
    content = f.read()

# Replace handle_action
content = re.sub(
    r'async fn handle_action\(\n\s*State\(state\): State<AppState>,\n\s*Json\(payload\): Json<ActionPayload>,\n\) -> impl IntoResponse {\n\s*let username = "admin"; // Mock auth',
    r'async fn handle_action(\n    State(state): State<AppState>,\n    axum::extract::Extension(auth): axum::extract::Extension<mitm_common::ipc::AuthResponse>,\n    Json(payload): Json<ActionPayload>,\n) -> impl IntoResponse {\n    let username = auth.username;',
    content
)

# Replace handle_backup
content = re.sub(
    r'async fn handle_backup\(State\(state\): State<AppState>\) -> impl IntoResponse {\n\s*let username = "admin"; // Mock auth',
    r'async fn handle_backup(State(state): State<AppState>, axum::extract::Extension(auth): axum::extract::Extension<mitm_common::ipc::AuthResponse>) -> impl IntoResponse {\n    let username = auth.username;',
    content
)

# Replace handle_restore
content = re.sub(
    r'async fn handle_restore\(\n\s*State\(state\): State<AppState>,\n\s*Json\(payload\): Json<RestorePayload>,\n\) -> impl IntoResponse {\n\s*let username = "admin"; // Mock auth',
    r'async fn handle_restore(\n    State(state): State<AppState>,\n    axum::extract::Extension(auth): axum::extract::Extension<mitm_common::ipc::AuthResponse>,\n    Json(payload): Json<RestorePayload>,\n) -> impl IntoResponse {\n    let username = auth.username;',
    content
)

# Replace handle_key_rotation
content = re.sub(
    r'async fn handle_key_rotation\(\n\s*State\(state\): State<AppState>,\n\s*Json\(payload\): Json<KeyRotationPayload>,\n\) -> impl IntoResponse {\n\s*let username = "admin"; // Mock auth',
    r'async fn handle_key_rotation(\n    State(state): State<AppState>,\n    axum::extract::Extension(auth): axum::extract::Extension<mitm_common::ipc::AuthResponse>,\n    Json(payload): Json<KeyRotationPayload>,\n) -> impl IntoResponse {\n    let username = auth.username;',
    content
)

with open('core-layer/mitm_http-server/src/handlers/admin.rs', 'w') as f:
    f.write(content)
