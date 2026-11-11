use axum::{
    Json,
    extract::{FromRequest, Request, rejection::JsonRejection},
    http::StatusCode,
};
use serde::de::DeserializeOwned;

use crate::error::{ApiErrorResponse, AppError, request_id_from_extensions};

pub struct ApiJson<T>(pub T);

impl<T, S> FromRequest<S> for ApiJson<T>
where
    T: DeserializeOwned,
    S: Send + Sync,
{
    type Rejection = ApiErrorResponse;

    async fn from_request(request: Request, state: &S) -> Result<Self, Self::Rejection> {
        let request_id = request_id_from_extensions(request.extensions());
        match Json::<T>::from_request(request, state).await {
            Ok(Json(value)) => Ok(Self(value)),
            Err(rejection) => Err(ApiErrorResponse::with_request_id(
                map_rejection(&rejection),
                request_id,
            )),
        }
    }
}

fn map_rejection(rejection: &JsonRejection) -> AppError {
    match rejection.status() {
        StatusCode::PAYLOAD_TOO_LARGE => AppError::PayloadTooLarge,
        StatusCode::UNSUPPORTED_MEDIA_TYPE => AppError::UnsupportedMediaType,
        _ => AppError::InvalidBody,
    }
}
