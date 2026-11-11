use axum::{
    Json,
    extract::{Extension, State},
};
use serde::Serialize;
use tower_http::request_id::RequestId;

use crate::{error::request_id, response::ApiResponse, state::AppState};

const SERVICE_NAME: &str = "jlu-dela-api";
const API_VERSION: &str = "v1";

#[derive(Debug, Serialize)]
pub struct MetaData {
    pub service: &'static str,
    pub version: &'static str,
    pub api_version: &'static str,
    pub build_id: String,
}

pub async fn get(
    State(state): State<AppState>,
    Extension(request_id_value): Extension<RequestId>,
) -> Json<ApiResponse<MetaData>> {
    Json(ApiResponse::new(
        MetaData {
            service: SERVICE_NAME,
            version: env!("CARGO_PKG_VERSION"),
            api_version: API_VERSION,
            build_id: state.build_id.to_string(),
        },
        request_id(&request_id_value),
    ))
}
