use serde::Serialize;

#[derive(Debug, Serialize)]
pub struct ApiResponse<T> {
    pub data: T,
    pub meta: ResponseMeta,
}

#[derive(Debug, Serialize)]
pub struct ResponseMeta {
    pub request_id: String,
}

impl<T> ApiResponse<T> {
    pub fn new(data: T, request_id: impl Into<String>) -> Self {
        Self {
            data,
            meta: ResponseMeta {
                request_id: request_id.into(),
            },
        }
    }
}
