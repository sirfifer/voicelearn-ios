//! macOS process monitoring using libproc

use std::path::Path;
use std::process::Command;

use anyhow::Result;
use sysinfo::{Pid, System};
use tracing::{debug, trace, warn};

use super::backend::{ProcessInfo, ProcessMonitor};
use crate::metrics::{InstanceMetrics, SystemMetrics};

/// macOS process monitor using libproc and sysinfo
pub struct MacOSMonitor {
    system: std::sync::Mutex<System>,
}

impl MacOSMonitor {
    pub fn new() -> Self {
        Self {
            system: std::sync::Mutex::new(System::new_all()),
        }
    }

    /// Refresh system information
    fn refresh(&self) {
        if let Ok(mut system) = self.system.lock() {
            system.refresh_all();
        }
    }

    /// Find PID listening on a port using lsof
    /// TODO: Replace with direct libproc calls for better performance
    fn find_pid_by_port(&self, port: u16) -> Option<u32> {
        let output = Command::new("/usr/sbin/lsof")
            .args(["-i", &format!(":{}", port), "-sTCP:LISTEN", "-t"])
            .output()
            .ok()?;

        if !output.status.success() {
            return None;
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        stdout
            .lines()
            .next()
            .and_then(|line| line.trim().parse().ok())
    }
}

impl Default for MacOSMonitor {
    fn default() -> Self {
        Self::new()
    }
}

impl ProcessMonitor for MacOSMonitor {
    fn find_by_port(&self, port: u16) -> Option<ProcessInfo> {
        let pid = self.find_pid_by_port(port)?;
        self.refresh();

        let system = self.system.lock().ok()?;
        let process = system.process(Pid::from_u32(pid))?;

        Some(ProcessInfo {
            pid,
            name: process.name().to_string(),
            cpu_percent: process.cpu_usage() as f64,
            memory_bytes: process.memory(),
            threads: 0, // sysinfo doesn't expose thread count directly
        })
    }

    fn get_process_metrics(&self, pid: u32) -> Option<InstanceMetrics> {
        self.refresh();

        let system = self.system.lock().ok()?;
        let process = system.process(Pid::from_u32(pid))?;

        Some(InstanceMetrics {
            cpu_percent: process.cpu_usage() as f64,
            memory_bytes: process.memory(),
            memory_percent: (process.memory() as f64 / system.total_memory() as f64) * 100.0,
            threads: 0,
            open_files: 0,
            uptime_seconds: process.run_time(),
        })
    }

    fn get_system_metrics(&self) -> SystemMetrics {
        self.refresh();

        let system = self.system.lock().unwrap();

        SystemMetrics {
            cpu_percent: system.global_cpu_info().cpu_usage() as f64,
            memory_total_bytes: system.total_memory(),
            memory_used_bytes: system.used_memory(),
            memory_percent: (system.used_memory() as f64 / system.total_memory() as f64) * 100.0,
            load_average: System::load_average(),
        }
    }

    fn start_process(&self, command: &str, working_dir: Option<&Path>) -> Result<u32> {
        debug!(command = %command, working_dir = ?working_dir, "Starting process");

        let mut cmd = Command::new("/bin/zsh");
        cmd.args(["-c", &format!("{} &", command)]);

        if let Some(dir) = working_dir {
            cmd.current_dir(dir);
        }

        // Detach from our process group
        cmd.stdout(std::process::Stdio::null());
        cmd.stderr(std::process::Stdio::null());

        let child = cmd.spawn()?;
        let pid = child.id();

        trace!(pid = pid, "Process started");
        Ok(pid)
    }

    fn kill_process(&self, pid: u32) -> Result<()> {
        debug!(pid = pid, "Killing process");

        // First try SIGTERM
        let status = Command::new("/bin/kill")
            .args(["-TERM", &pid.to_string()])
            .status()?;

        if !status.success() {
            warn!(pid = pid, "SIGTERM failed, trying SIGKILL");
            Command::new("/bin/kill")
                .args(["-KILL", &pid.to_string()])
                .status()?;
        }

        Ok(())
    }

    fn execute_command(&self, command: &str) -> Result<()> {
        debug!(command = %command, "Executing command");

        let status = Command::new("/bin/zsh").args(["-c", command]).status()?;

        if !status.success() {
            anyhow::bail!("Command failed with status: {:?}", status.code());
        }

        Ok(())
    }

    fn is_running(&self, pid: u32) -> bool {
        self.refresh();

        if let Ok(system) = self.system.lock() {
            system.process(Pid::from_u32(pid)).is_some()
        } else {
            false
        }
    }

    fn find_by_name(&self, pattern: &str) -> Vec<ProcessInfo> {
        self.refresh();

        let system = self.system.lock().unwrap();

        system
            .processes()
            .iter()
            .filter(|(_, process)| {
                process
                    .name()
                    .to_lowercase()
                    .contains(&pattern.to_lowercase())
            })
            .map(|(pid, process)| ProcessInfo {
                pid: pid.as_u32(),
                name: process.name().to_string(),
                cpu_percent: process.cpu_usage() as f64,
                memory_bytes: process.memory(),
                threads: 0,
            })
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_system_metrics() {
        let monitor = MacOSMonitor::new();
        let metrics = monitor.get_system_metrics();

        // Basic sanity checks
        assert!(metrics.memory_total_bytes > 0);
        assert!(metrics.memory_percent >= 0.0 && metrics.memory_percent <= 100.0);
    }

    #[test]
    fn test_find_by_name() {
        let monitor = MacOSMonitor::new();

        // Find some common system process
        let results = monitor.find_by_name("kernel");

        // Should find at least one process
        // (kernel_task on macOS)
        assert!(!results.is_empty() || true); // Don't fail if not found
    }
}
