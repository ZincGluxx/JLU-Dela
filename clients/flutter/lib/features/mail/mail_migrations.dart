import '../../core/storage/local_database.dart';

/// 邮箱本地缓存：账户参数、文件夹、近端邮件窗口与草稿。
///
/// 版本段 30–39 归邮箱（见 `docs/local-data.md`）。凭据不落库，见
/// `MailCredentialStore`；这里只存连接参数与本地缓存。
const List<LocalMigration> mailMigrations = [
  LocalMigration(30, [
    '''
CREATE TABLE mail_accounts(
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  address TEXT NOT NULL,
  display_name TEXT,
  imap_host TEXT NOT NULL,
  imap_port INTEGER NOT NULL,
  smtp_host TEXT NOT NULL,
  smtp_port INTEGER NOT NULL,
  created_at_utc INTEGER NOT NULL,
  updated_at_utc INTEGER NOT NULL,
  last_connected_at_utc INTEGER,
  last_error_code TEXT,
  last_error_message TEXT,
  UNIQUE(user_id, address)
)
''',
    'CREATE INDEX mail_accounts_user ON mail_accounts(user_id, address)',
    '''
CREATE TABLE mail_folders(
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  account_id TEXT NOT NULL REFERENCES mail_accounts(id) ON DELETE CASCADE,
  path TEXT NOT NULL,
  name TEXT NOT NULL,
  special_use TEXT,
  uid_validity TEXT,
  total INTEGER,
  unread INTEGER,
  synced_at_utc INTEGER,
  UNIQUE(account_id, path)
)
''',
    'CREATE INDEX mail_folders_account ON mail_folders(account_id, path)',
    '''
CREATE TABLE mail_messages(
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  account_id TEXT NOT NULL,
  folder_id TEXT NOT NULL REFERENCES mail_folders(id) ON DELETE CASCADE,
  uid INTEGER NOT NULL,
  message_id TEXT,
  subject TEXT,
  sender_name TEXT,
  sender_address TEXT,
  to_addresses TEXT NOT NULL DEFAULT '[]',
  cc_addresses TEXT NOT NULL DEFAULT '[]',
  sent_at_utc INTEGER,
  seen INTEGER NOT NULL DEFAULT 0,
  flagged INTEGER NOT NULL DEFAULT 0,
  has_attachments INTEGER NOT NULL DEFAULT 0,
  snippet TEXT,
  body_text TEXT,
  body_html TEXT,
  attachments TEXT NOT NULL DEFAULT '[]',
  size INTEGER,
  body_fetched_at_utc INTEGER,
  observed_at_utc INTEGER NOT NULL,
  UNIQUE(folder_id, uid)
)
''',
    'CREATE INDEX mail_messages_folder_sent ON mail_messages(folder_id, sent_at_utc DESC)',
    'CREATE INDEX mail_messages_user_sent ON mail_messages(user_id, sent_at_utc DESC)',
  ]),
  LocalMigration(31, [
    '''
CREATE TABLE mail_drafts(
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  account_id TEXT NOT NULL,
  recipient_text TEXT NOT NULL DEFAULT '',
  subject TEXT NOT NULL DEFAULT '',
  body_text TEXT NOT NULL DEFAULT '',
  body_html TEXT NOT NULL DEFAULT '',
  in_reply_to TEXT,
  attachments TEXT NOT NULL DEFAULT '[]',
  send_state TEXT NOT NULL CHECK (send_state IN ('editing','sending','failed','sent')),
  last_error_code TEXT,
  last_error_message TEXT,
  created_at_utc INTEGER NOT NULL,
  updated_at_utc INTEGER NOT NULL
)
''',
    'CREATE INDEX mail_drafts_user_updated ON mail_drafts(user_id, updated_at_utc DESC)',
  ]),
];
