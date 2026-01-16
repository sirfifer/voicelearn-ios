//! Resource metrics collection

use serde::{Deserialize, Serialize};
use sysinfo::LoadAvg;

/// Metrics for a specific service instance
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InstanceMetrics {
    /// CPU usage percentage
    pub cpu_percent: f64,

    /// Memory usage in bytes
    pub memory_bytes: u64,

    /// Memory usage as percentage of total system memory
    pub memory_percent: f64,

    /// Number of threads
    pub threads: u32,

    /// Number of open file descriptors
    pub open_files: u32,

    /// Process uptime in seconds
    pub uptime_seconds: u64,
}

impl InstanceMetrics {
    /// Get memory usage in megabytes
    pub fn memory_mb(&self) -> u64 {
        self.memory_bytes / (1024 * 1024)
    }

    /// Get formatted uptime string
    pub fn uptime_string(&self) -> String {
        let secs = self.uptime_seconds;
        if secs < 60 {
            format!("{}s", secs)
        } else if secs < 3600 {
            format!("{}m {}s", secs / 60, secs % 60)
        } else if secs < 86400 {
            format!("{}h {}m", secs / 3600, (secs % 3600) / 60)
        } else {
            format!("{}d {}h", secs / 86400, (secs % 86400) / 3600)
        }
    }
}

/// System-wide metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SystemMetrics {
    /// Overall CPU usage percentage
    pub cpu_percent: f64,

    /// Total system memory in bytes
    pub memory_total_bytes: u64,

    /// Used system memory in bytes
    pub memory_used_bytes: u64,

    /// Memory usage percentage
    pub memory_percent: f64,

    /// Load average (1, 5, 15 minutes)
    #[serde(skip)]
    pub load_average: LoadAvg,
}

impl SystemMetrics {
    /// Get total memory in gigabytes
    pub fn memory_total_gb(&self) -> f64 {
        self.memory_total_bytes as f64 / (1024.0 * 1024.0 * 1024.0)
    }

    /// Get used memory in gigabytes
    pub fn memory_used_gb(&self) -> f64 {
        self.memory_used_bytes as f64 / (1024.0 * 1024.0 * 1024.0)
    }

    /// Get available memory in bytes
    pub fn memory_available_bytes(&self) -> u64 {
        self.memory_total_bytes
            .saturating_sub(self.memory_used_bytes)
    }

    /// Get load average as tuple (1m, 5m, 15m)
    pub fn load_average_tuple(&self) -> (f64, f64, f64) {
        (
            self.load_average.one,
            self.load_average.five,
            self.load_average.fifteen,
        )
    }
}

impl Default for SystemMetrics {
    fn default() -> Self {
        Self {
            cpu_percent: 0.0,
            memory_total_bytes: 0,
            memory_used_bytes: 0,
            memory_percent: 0.0,
            load_average: LoadAvg {
                one: 0.0,
                five: 0.0,
                fifteen: 0.0,
            },
        }
    }
}

/// Aggregated metrics summary for the dashboard
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MetricsSummary {
    /// System metrics
    pub system: SystemMetrics,

    /// Number of running instances
    pub running_count: usize,

    /// Number of stopped instances
    pub stopped_count: usize,

    /// Number of instances with errors
    pub error_count: usize,

    /// Total CPU usage across all monitored instances
    pub total_instance_cpu: f64,

    /// Total memory usage across all monitored instances (bytes)
    pub total_instance_memory: u64,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_instance_metrics() {
        let metrics = InstanceMetrics {
            cpu_percent: 25.5,
            memory_bytes: 256 * 1024 * 1024, // 256 MB
            memory_percent: 3.2,
            threads: 10,
            open_files: 50,
            uptime_seconds: 3665, // 1h 1m 5s
        };

        assert_eq!(metrics.memory_mb(), 256);
        assert_eq!(metrics.uptime_string(), "1h 1m");
    }

    #[test]
    fn test_uptime_formatting() {
        let cases = [
            (30, "30s"),
            (90, "1m 30s"),
            (3600, "1h 0m"),
            (3665, "1h 1m"),
            (86400, "1d 0h"),
            (90061, "1d 1h"),
        ];

        for (secs, expected) in cases {
            let metrics = InstanceMetrics {
                cpu_percent: 0.0,
                memory_bytes: 0,
                memory_percent: 0.0,
                threads: 0,
                open_files: 0,
                uptime_seconds: secs,
            };
            assert_eq!(
                metrics.uptime_string(),
                expected,
                "Failed for {} seconds",
                secs
            );
        }
    }
}
