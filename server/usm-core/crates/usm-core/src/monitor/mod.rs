//! Process monitoring with platform-specific backends

mod backend;

#[cfg(target_os = "macos")]
mod macos;

#[cfg(target_os = "linux")]
mod linux;

pub use backend::ProcessMonitor;

use std::sync::Arc;

/// Create the appropriate process monitor for the current platform
pub fn create_monitor() -> Arc<dyn ProcessMonitor> {
    #[cfg(target_os = "macos")]
    {
        Arc::new(macos::MacOSMonitor::new())
    }

    #[cfg(target_os = "linux")]
    {
        Arc::new(linux::LinuxMonitor::new())
    }

    #[cfg(not(any(target_os = "macos", target_os = "linux")))]
    {
        compile_error!("Unsupported platform: only macOS and Linux are supported")
    }
}
