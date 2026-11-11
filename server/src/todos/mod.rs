//! 个人待办（owner: E）。
//!
//! - 端点：`GET/POST /api/v1/todos`、`PATCH/DELETE /api/v1/todos/{id}`
//! - 创建走 `Idempotency-Key`，幂等记录与业务写入同一事务
//! - 更新与删除走乐观并发（`revision` / `If-Match`），冲突返回 `409 REVISION_CONFLICT`
//!   并附服务器当前版本，客户端据此保留用户草稿
//! - 截止信息三态：`none` / `date_only` / `exact`，见 `time-semantics.md` 第 5 节

pub mod error;
pub mod handlers;
pub mod model;
pub mod repo;

#[cfg(test)]
mod tests;

pub use handlers::router;
