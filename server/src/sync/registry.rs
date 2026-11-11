use std::{collections::BTreeMap, future::Future, pin::Pin, sync::Arc};

use serde_json::Value;
use uuid::Uuid;

pub struct SyncContext<'a> {
    pub job_id: Uuid,
    pub user_id: Uuid,
    pub source: &'a str,
    pub resource: &'a str,
    pub scope: &'a Value,
}

#[derive(Debug)]
pub struct SyncOutcome {
    pub snapshot_version: Option<i64>,
    pub complete: bool,
}

#[derive(Debug)]
pub struct SyncFailure {
    pub code: &'static str,
    pub retryable: bool,
}

impl SyncFailure {
    pub fn new(code: &'static str, retryable: bool) -> Self {
        Self { code, retryable }
    }
}

pub type SyncFuture<'a> =
    Pin<Box<dyn Future<Output = Result<SyncOutcome, SyncFailure>> + Send + 'a>>;

pub trait SyncHandler: Send + Sync {
    fn execute<'a>(&'a self, context: SyncContext<'a>) -> SyncFuture<'a>;
}

struct Target {
    resources: &'static [&'static str],
    handler: Arc<dyn SyncHandler>,
}

#[derive(Default)]
pub struct SyncRegistry {
    targets: BTreeMap<&'static str, Target>,
}

impl SyncRegistry {
    pub fn empty() -> Self {
        Self::default()
    }

    pub fn register(
        mut self,
        source: &'static str,
        resources: &'static [&'static str],
        handler: Arc<dyn SyncHandler>,
    ) -> Self {
        self.targets.insert(source, Target { resources, handler });
        self
    }

    pub fn is_empty(&self) -> bool {
        self.targets.is_empty()
    }

    pub fn supports_source(&self, source: &str) -> bool {
        self.targets.contains_key(source)
    }

    pub fn supports(&self, source: &str, resource: &str) -> bool {
        self.targets
            .get(source)
            .is_some_and(|target| target.resources.contains(&resource))
    }

    pub fn handler(&self, source: &str) -> Option<Arc<dyn SyncHandler>> {
        self.targets
            .get(source)
            .map(|target| target.handler.clone())
    }
}
