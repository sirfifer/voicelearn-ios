//! Process monitor trait - abstraction over platform-specific implementations

use std::path::Path;

use anyhow::Result;

use crate::metrics::{InstanceMetrics, SystemMetrics};

/// Information about a process
#[derive(Debug, Clone)]
pub struct ProcessInfo {
    pub pid: u32,
    pub name: String,
    pub cpu_percent: f64,
    pub memory_bytes: u64,
    pub threads: u32,
}

/// Trait for platform-specific process monitoring
///
/// Implementations should use native APIs (libproc on macOS, procfs on Linux)
/// rather than spawning external processes for efficiency.
pub trait ProcessMonitor: Send + Sync {
    /// Find a process by the port it's listening on
    ///
    /// Returns the process info if found, None otherwise.
    fn find_by_port(&self, port: u16) -> Option<ProcessInfo>;

    /// Get metrics for a specific process by PID
    fn get_process_metrics(&self, pid: u32) -> Option<InstanceMetrics>;

    /// Get system-wide metrics (CPU, memory, etc.)
    fn get_system_metrics(&self) -> SystemMetrics;

    /// Start a process with the given command
    ///
    /// Returns the PID of the started process.
    fn start_process(&self, command: &str, working_dir: Option<&Path>) -> Result<u32>;

    /// Kill a process by PID
    fn kill_process(&self, pid: u32) -> Result<()>;

    /// Execute a command (for custom stop commands)
    fn execute_command(&self, command: &str) -> Result<()>;

    /// Check if a process is still running
    fn is_running(&self, pid: u32) -> bool;

    /// Get a list of all processes matching a pattern
    fn find_by_name(&self, pattern: &str) -> Vec<ProcessInfo>;
}
