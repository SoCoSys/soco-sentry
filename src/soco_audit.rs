// SoCo Sentry — local connection log.
//
// Records who connected to THIS machine and when, so the log is visible on the
// device itself (Audit Log tab) even when the portal is unreachable. Local mirror
// of the audit the client already posts to {api-server}/api/audit/conn (see
// server/connection.rs post_conn_audit); the portal keeps the fleet-wide copy.
//
// Deliberately dependency-free and best-effort: a logging failure must never
// affect a remote session. Stored as a small JSON array, newest last, capped.

use hbb_common::{config::Config, log};
use serde::{Deserialize, Serialize};
use std::sync::Mutex;

const LOG_FILE: &str = "soco_connections.json";
const MAX_ENTRIES: usize = 500;

lazy_static::lazy_static! {
    static ref LOCK: Mutex<()> = Mutex::new(());
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ConnEntry {
    pub started: i64,
    #[serde(default)]
    pub ended: i64,
    #[serde(default)]
    pub peer_id: String,
    #[serde(default)]
    pub peer_name: String,
    #[serde(default)]
    pub ip: String,
    #[serde(default)]
    pub conn_type: String,
    #[serde(default)]
    pub conn_id: i32,
}

/// Shared location for the log.
///
/// IMPORTANT: the log is WRITTEN by the service process (SYSTEM) but READ by the
/// UI process (the logged-in user) — those have different per-user config dirs,
/// so Config::path() alone would give each of them a different file. On Windows
/// we therefore use a machine-wide folder under %ProgramData%, which SYSTEM can
/// write and users can read. Everywhere else we fall back to the config dir.
fn log_path() -> std::path::PathBuf {
    #[cfg(target_os = "windows")]
    {
        if let Ok(pd) = std::env::var("ProgramData") {
            let dir = std::path::Path::new(&pd).join(crate::get_app_name());
            if !dir.exists() {
                let _ = std::fs::create_dir_all(&dir);
            }
            if dir.exists() {
                return dir.join(LOG_FILE);
            }
        }
    }
    Config::path(LOG_FILE)
}

fn now() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

fn load() -> Vec<ConnEntry> {
    match std::fs::read_to_string(log_path()) {
        Ok(s) => serde_json::from_str::<Vec<ConnEntry>>(&s).unwrap_or_default(),
        Err(_) => Vec::new(),
    }
}

fn save(entries: &[ConnEntry]) {
    let start = entries.len().saturating_sub(MAX_ENTRIES);
    if let Ok(s) = serde_json::to_string(&entries[start..]) {
        let path = log_path();
        let tmp = path.with_extension("tmp");
        if std::fs::write(&tmp, s).is_ok() {
            let _ = std::fs::rename(&tmp, &path);
        }
    }
}

/// A new inbound connection was accepted (not yet authenticated).
pub fn conn_opened(conn_id: i32, ip: &str) {
    let _g = LOCK.lock();
    let mut v = load();
    if v.iter().any(|e| e.conn_id == conn_id && e.ended == 0) {
        return;
    }
    v.push(ConnEntry {
        started: now(),
        ended: 0,
        ip: ip.to_owned(),
        conn_id,
        ..Default::default()
    });
    save(&v);
}

/// The peer authenticated — we now know who it is and the session kind.
pub fn conn_authed(conn_id: i32, peer_id: &str, peer_name: &str, conn_type: &str) {
    let _g = LOCK.lock();
    let mut v = load();
    if let Some(e) = v.iter_mut().rev().find(|e| e.conn_id == conn_id && e.ended == 0) {
        e.peer_id = peer_id.to_owned();
        e.peer_name = peer_name.to_owned();
        e.conn_type = conn_type.to_owned();
    } else {
        v.push(ConnEntry {
            started: now(),
            peer_id: peer_id.to_owned(),
            peer_name: peer_name.to_owned(),
            conn_type: conn_type.to_owned(),
            conn_id,
            ..Default::default()
        });
    }
    save(&v);
}

/// The connection closed.
pub fn conn_closed(conn_id: i32) {
    let _g = LOCK.lock();
    let mut v = load();
    let t = now();
    if let Some(e) = v.iter_mut().rev().find(|e| e.conn_id == conn_id && e.ended == 0) {
        e.ended = t;
    }
    save(&v);
}

/// Whole log as a JSON array string, newest FIRST (for the UI).
pub fn read_json() -> String {
    let _g = LOCK.lock();
    let mut v = load();
    v.reverse();
    serde_json::to_string(&v).unwrap_or_else(|_| "[]".to_owned())
}

/// Erase the local log (UI "Clear" action).
pub fn clear() {
    let _g = LOCK.lock();
    if let Err(e) = std::fs::remove_file(log_path()) {
        log::debug!("clear connection log: {}", e);
    }
}
