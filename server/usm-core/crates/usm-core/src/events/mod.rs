//! Event system for broadcasting service state changes

mod bus;

pub use bus::EventBus;

use serde::{Deserialize, Serialize};

use crate::service::ServiceStatus;

/// Events that can be broadcast to subscribers
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ServiceEvent {
    // Instance lifecycle
    InstanceCreated {
        instance_id: String,
        template_id: String,
    },
    InstanceRemoved {
        instance_id: String,
    },
    StatusChanged {
        instance_id: String,
        status: ServiceStatus,
        pid: Option<u32>,
    },

    // Metrics
    MetricsUpdated {
        instance_id: String,
        cpu_percent: f64,
        memory_mb: u64,
    },

    // Health
    HealthChanged {
        instance_id: String,
        healthy: bool,
        message: Option<String>,
    },

    // Errors
    Error {
        instance_id: Option<String>,
        message: String,
    },

    // Template changes
    TemplateRegistered {
        template_id: String,
    },
    TemplateRemoved {
        template_id: String,
    },

    // Config changes
    ConfigReloaded,
}

impl ServiceEvent {
    /// Get the instance ID associated with this event, if any
    pub fn instance_id(&self) -> Option<&str> {
        match self {
            ServiceEvent::InstanceCreated { instance_id, .. } => Some(instance_id),
            ServiceEvent::InstanceRemoved { instance_id } => Some(instance_id),
            ServiceEvent::StatusChanged { instance_id, .. } => Some(instance_id),
            ServiceEvent::MetricsUpdated { instance_id, .. } => Some(instance_id),
            ServiceEvent::HealthChanged { instance_id, .. } => Some(instance_id),
            ServiceEvent::Error { instance_id, .. } => instance_id.as_deref(),
            ServiceEvent::TemplateRegistered { .. } => None,
            ServiceEvent::TemplateRemoved { .. } => None,
            ServiceEvent::ConfigReloaded => None,
        }
    }

    /// Get the event type name
    pub fn event_type(&self) -> &'static str {
        match self {
            ServiceEvent::InstanceCreated { .. } => "instance_created",
            ServiceEvent::InstanceRemoved { .. } => "instance_removed",
            ServiceEvent::StatusChanged { .. } => "status_changed",
            ServiceEvent::MetricsUpdated { .. } => "metrics_updated",
            ServiceEvent::HealthChanged { .. } => "health_changed",
            ServiceEvent::Error { .. } => "error",
            ServiceEvent::TemplateRegistered { .. } => "template_registered",
            ServiceEvent::TemplateRemoved { .. } => "template_removed",
            ServiceEvent::ConfigReloaded => "config_reloaded",
        }
    }
}
