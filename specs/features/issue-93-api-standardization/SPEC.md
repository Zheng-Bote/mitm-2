# Feature: API Standardization – RMM Level 2 & Unified JSON Response Envelope (Issue #93)

**Source:** [Zheng-Bote/mitm_core-layer#93](https://github.com/Zheng-Bote/mitm_core-layer/issues/93)
**Status:** Specified (Phase 1 anchored in SpecDD)
**Affected Components:** `core-layer/mitm_http-server`, `admin-frontend/mitm_fe_web`, `admin-frontend/mitm_fe_cpp`

## 1. Feature Intent

Standardize the HTTP REST API of `mitm_http-server` (from v3 onwards) on **Richardson Maturity Model (RMM) Level 2** and a unified **JSON:API-derived response object** (`id`, `status`, `code`, `title`, `detail`, `meta`, `data`) across both success (`2xx`) and error (`4xx`/`5xx`) responses.

## 2. Response Envelope Contract

```json
{
  "id": "01933a7c-8d42-7f00-9a1b-4c5d6e7f8091",
  "status": 200,
  "code": "OK",
  "title": "Success",
  "detail": null,
  "meta": {
    "timestamp": "2026-11-17T11:30:00Z",
    "version": "3.5.0"
  },
  "data": {}
}
```

| Field | Type | Description |
|---|---|---|
| `id` | `string` (UUID) | Unique Request-ID of the HTTP call (matches `X-Request-ID` header). |
| `status` | `u16` | Numeric HTTP status code (`200`, `201`, `202`, `400`, `401`, `403`, `404`, `409`, `422`, `429`, `500`, `503`). |
| `code` | `string` | Machine-readable `UPPER_SNAKE_CASE` status/error code (`OK`, `CREATED`, `ACCEPTED`, `UPDATED`, `DELETED`, `BAD_REQUEST`, `AUTH_REQUIRED`, `RBAC_FORBIDDEN`, `USER_INACTIVE`, `NOT_FOUND`, `CONFLICT`, `VALIDATION_FAILED`, `RATE_LIMITED`, `INTERNAL_ERROR`, `SERVICE_UNAVAILABLE`). |
| `title` | `string` | Short human-readable summary. |
| `detail` | `string \| null` | Specific explanation for this occurrence (`null` when not needed). |
| `meta` | `object` | `{ "timestamp": "<RFC3339>", "version": "<semver>" }` plus optional pagination fields (`count`, `limit`, `offset`). |
| `data` | `object \| array \| null` | Resource payload on `2xx`; `null` on `4xx`/`5xx` or status-only responses. |

### Explicit Non-Envelope Exceptions
1. **Binary Content Negotiation (`Accept: application/x-flatbuffers`):** `/api/v1/logs/*` and `/api/v1/dlq` return `application/octet-stream` on `200 OK` (errors `4xx`/`5xx` always return the JSON envelope).
2. **Browser Navigation Redirects:** `/api/v1/auth/oidc/login` and `/api/v1/auth/oidc/callback` return HTTP `302`/`303` redirects.
3. **Static SPA Assets & `/health`:** Return static assets / lightweight load-balancer health status.

## 3. RMM Level 2 Endpoint Standardization

| Area | Current | Standardized (RMM Level 2) | HTTP Status |
|---|---|---|---|
| Assign user roles | `POST /api/v1/iam/assign-role` | `PUT /api/v1/iam/users/:id/roles` | `200 OK` (`UPDATED`) |
| Topic dependency update/delete | `DELETE .../topic-dependencies?topic=X` | `PUT` / `DELETE /api/v1/config/transformations/topic-dependencies/:topic` | `200 OK` (`UPDATED` / `DELETED`) |
| Single job update | `POST /api/v1/jobs` (bulk only) | `PUT /api/v1/jobs/:name` (single) & `POST /api/v1/jobs` | `200 OK` / `201 Created` |
| Async job triggers | `POST /api/v1/jobs/:name/execute` & `/stop` | `POST /api/v1/jobs/:name/execute` & `/stop` | `202 Accepted` (`ACCEPTED`) |
| Async file upload | `POST /api/v1/jobs/upload/source_file` | `POST /api/v1/jobs/upload/source_file` | `202 Accepted` (`ACCEPTED`) |
| Resource creation | `POST /api/v1/iam/users`, `credentials`, `targets` | Same paths + `Location` header | `201 Created` (`CREATED`) |
| Semantic validation error | `400 Bad Request` | `422 Unprocessable Entity` (`VALIDATION_FAILED`) | `422 Unprocessable Entity` |
