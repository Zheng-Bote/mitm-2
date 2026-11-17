# Implementation Plan: API Standardization (Issue #93)

## 1. Spec Chain & Authority

- `mitm-2.sdd` → `core-layer/core-layer.sdd` → `core-layer/mitm_http-server/mitm_http-server.sdd` → `core-layer/mitm_http-server/specs/api_spec.sdd`
- `mitm-2.sdd` → `admin-frontend/admin-frontend.sdd` → `admin-frontend/mitm_fe_web/mitm_fe_web.sdd` & `admin-frontend/mitm_fe_cpp/mitm_fe_cpp.sdd`

## 2. Staged Rollout Across Repositories

### Phase 1: SpecDD Contract & Core Response Infrastructure (`core-layer/mitm_http-server`)
1. **`RequestId` Middleware (`src/main.rs` / `src/response.rs`):**
   - Generate a UUIDv4 per request, insert it into request extensions (`RequestId(String)`), and attach `X-Request-ID` to every response.
   - Inject `RequestId` automatically into `ApiResponse<T>` and `ApiError` via response middleware or `IntoResponse`.
2. **`ApiResponse<T>` & `ApiError` (`src/handlers/response.rs`):**
   - Define `ApiResponse<T>` and `ApiMeta` serializing `{ id, status, code, title, detail, meta, data }`.
   - Implement `IntoResponse` for `ApiResponse<T>` and `ApiError` so all handlers and middlewares (`readiness_middleware`, `auth_middleware`, `authz_middleware`, `rate_limit_middleware`) return the exact same JSON structure.
3. **RMM Level 2 Route & Status Code Alignment (`src/handlers/api_v1/*`):**
   - Add `PUT /api/v1/iam/users/:id/roles`, `PUT /api/v1/jobs/:name`, `PUT /api/v1/config/transformations/topic-dependencies/:topic`, and `DELETE /api/v1/config/transformations/topic-dependencies/:topic` (keeping legacy aliases temporarily deprecated if needed for transition).
   - Return `201 Created` on resource creation and `202 Accepted` on async scheduler triggers.

### Phase 2: Web Frontend Adaptation (`admin-frontend/mitm_fe_web`)
1. Add/update an Angular `HttpInterceptor` that unwraps `response.data` for `2xx` JSON responses (when the body is an `ApiResponse` envelope) and maps error envelopes (`code`, `title`, `detail`, `id`) to user-facing notifications.
2. Switch role assignment and topic-dependency calls to the new RMM Level 2 paths.

### Phase 3: C++ Admin Client Adaptation (`admin-frontend/mitm_fe_cpp`)
1. Update the central JSON response parser in `mitm_fe_cpp` to read `.data` on `2xx` and `.code` / `.detail` / `.id` on `4xx`/`5xx`.
