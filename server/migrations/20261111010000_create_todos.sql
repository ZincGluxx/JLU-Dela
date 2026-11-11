-- 待办与幂等记录（E01）。写入路径见 src/todos/repo.rs。
-- 迁移由 A 审核后执行：本服务不在启动时自动迁移。
-- 时间戳晚于 20261111000000_create_identity.sql：全新库先建 users 再建 todos。

create table todos (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references users (id) on delete cascade,
    title text not null,
    notes text not null default '',
    due_kind text not null default 'none',
    due_date date,
    due_at timestamptz,
    color text,
    completed boolean not null default false,
    show_in_calendar boolean not null default true,
    revision integer not null default 1,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,
    constraint todos_due_kind_check check (due_kind in ('none', 'date_only', 'exact')),
    -- 三态互斥：due_kind 判别，另两个字段必须恰好是它要求的那一个
    constraint todos_due_shape_check check (
        (due_kind = 'none' and due_date is null and due_at is null)
        or (due_kind = 'date_only' and due_date is not null and due_at is null)
        or (due_kind = 'exact' and due_date is null and due_at is not null)
    )
);

create index todos_user_completed_due_idx
    on todos (user_id, completed, due_at asc nulls last)
    where deleted_at is null;

create index todos_user_calendar_idx
    on todos (user_id, due_at)
    where deleted_at is null and show_in_calendar;

-- 幂等记录保留 24 小时，清理任务不在本模块范围。
-- `status_code` / `response` 允许为空：占位行先写入，待办建成后在同一事务里回填，
-- 因此「已占位未完成」是可观察的中间态，不能声明成 not null。
create table idempotency_keys (
    user_id uuid not null references users (id) on delete cascade,
    endpoint text not null,
    key uuid not null,
    request_hash text not null,
    status_code smallint,
    response jsonb,
    created_at timestamptz not null default now(),
    primary key (user_id, endpoint, key)
);

update service_meta set value = '3', updated_at = now() where key = 'schema_version';
