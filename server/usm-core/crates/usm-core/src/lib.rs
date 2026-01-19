//! USM Core - Cross-platform service manager library
//!
//! A high-performance, reliable service manager designed to run for months
//! without issues. Supports dynamic service templates and instances with
//! real-time monitoring via WebSocket.

pub mod config;
pub mod events;
pub mod metrics;
pub mod monitor;
pub mod server;
pub mod service;

// Re-export commonly used types for convenience
pub use metrics::{InstanceMetrics, SystemMetrics};
pub use service::{
    InstanceConfig, InstanceRegistry, ServiceCategory, ServiceInstance, ServiceStatus,
    ServiceTemplate, TemplateRegistry,
};

use std::path::Path;
use std::sync::Arc;

use anyhow::Result;
use tokio::sync::{broadcast, RwLock};
use tracing::{info, instrument};

use config::ConfigManager;
use events::{EventBus, ServiceEvent};
use monitor::ProcessMonitor;

/// Main USM Core instance
///
/// Thread-safe, designed for long-running operation.
pub struct UsmCore {
    templates: Arc<RwLock<TemplateRegistry>>,
    instances: Arc<RwLock<InstanceRegistry>>,
    monitor: Arc<dyn ProcessMonitor>,
    config_manager: Arc<ConfigManager>,
    event_bus: Arc<EventBus>,
}

impl UsmCore {
    /// Create a new USM Core instance from a config file
    #[instrument(skip_all, fields(config_path = %config_path.as_ref().display()))]
    pub async fn new(config_path: impl AsRef<Path>) -> Result<Self> {
        let config_path = config_path.as_ref();
        info!(
            "Initializing USM Core from config: {}",
            config_path.display()
        );

        // Initialize event bus first (other components will subscribe)
        let event_bus = Arc::new(EventBus::new(1024));

        // Load configuration
        let config_manager = Arc::new(ConfigManager::new(config_path, event_bus.clone())?);
        let (templates, instances) = config_manager.load().await?;

        // Create platform-specific process monitor
        let monitor = monitor::create_monitor();

        Ok(Self {
            templates: Arc::new(RwLock::new(templates)),
            instances: Arc::new(RwLock::new(instances)),
            monitor,
            config_manager,
            event_bus,
        })
    }

    /// Start the HTTP/WebSocket server
    pub async fn start_server(&self, port: u16) -> Result<()> {
        server::run_server(
            port,
            self.templates.clone(),
            self.instances.clone(),
            self.monitor.clone(),
            self.event_bus.clone(),
        )
        .await
    }

    // =========================================================================
    // TEMPLATE MANAGEMENT
    // =========================================================================

    /// List all registered templates
    pub async fn list_templates(&self) -> Vec<ServiceTemplate> {
        self.templates.read().await.list()
    }

    /// Get a specific template by ID
    pub async fn get_template(&self, id: &str) -> Option<ServiceTemplate> {
        self.templates.read().await.get(id)
    }

    /// Register a new template at runtime
    pub async fn register_template(&self, template: ServiceTemplate) -> Result<()> {
        let mut templates = self.templates.write().await;
        templates.register(template.clone())?;

        // Persist to config file
        self.config_manager.save_templates(&templates).await?;

        // Broadcast event
        self.event_bus.send(ServiceEvent::TemplateRegistered {
            template_id: template.id,
        });

        Ok(())
    }

    /// Remove a template (only if no instances exist)
    pub async fn remove_template(&self, id: &str) -> Result<()> {
        // Check for existing instances
        let instances = self.instances.read().await;
        if instances.has_instances_for_template(id) {
            anyhow::bail!("Cannot remove template '{}': instances exist", id);
        }
        drop(instances);

        let mut templates = self.templates.write().await;
        templates.remove(id)?;

        // Persist to config file
        self.config_manager.save_templates(&templates).await?;

        // Broadcast event
        self.event_bus.send(ServiceEvent::TemplateRemoved {
            template_id: id.to_string(),
        });

        Ok(())
    }

    // =========================================================================
    // INSTANCE MANAGEMENT
    // =========================================================================

    /// List all instances, optionally filtered by template
    pub async fn list_instances(&self, template_filter: Option<&str>) -> Vec<ServiceInstance> {
        let instances = self.instances.read().await;
        match template_filter {
            Some(template_id) => instances.list_by_template(template_id),
            None => instances.list(),
        }
    }

    /// Get a specific instance by ID
    pub async fn get_instance(&self, id: &str) -> Option<ServiceInstance> {
        self.instances.read().await.get(id)
    }

    /// Create a new instance from a template
    #[instrument(skip(self, config), fields(instance_id = %config.instance_id, template_id = %config.template_id))]
    pub async fn create_instance(&self, config: service::InstanceConfig) -> Result<String> {
        // Verify template exists
        let templates = self.templates.read().await;
        let template = templates
            .get(&config.template_id)
            .ok_or_else(|| anyhow::anyhow!("Template '{}' not found", config.template_id))?;

        // Check if template supports multiple instances
        if !template.supports_multiple {
            let instances = self.instances.read().await;
            if instances.has_instances_for_template(&config.template_id) {
                anyhow::bail!(
                    "Template '{}' does not support multiple instances",
                    config.template_id
                );
            }
        }
        drop(templates);

        // Create the instance
        let instance = ServiceInstance::from_config(config.clone())?;
        let instance_id = instance.id.clone();

        let mut instances = self.instances.write().await;
        instances.add(instance)?;

        // Persist to config file
        self.config_manager.save_instances(&instances).await?;

        // Broadcast event
        self.event_bus.send(ServiceEvent::InstanceCreated {
            instance_id: instance_id.clone(),
            template_id: config.template_id,
        });

        info!(instance_id = %instance_id, "Instance created");
        Ok(instance_id)
    }

    /// Remove an instance (stops if running)
    #[instrument(skip(self), fields(instance_id = %id))]
    pub async fn remove_instance(&self, id: &str) -> Result<()> {
        // Stop if running
        self.stop_instance(id).await.ok();

        let mut instances = self.instances.write().await;
        instances.remove(id)?;

        // Persist to config file
        self.config_manager.save_instances(&instances).await?;

        // Broadcast event
        self.event_bus.send(ServiceEvent::InstanceRemoved {
            instance_id: id.to_string(),
        });

        info!(instance_id = %id, "Instance removed");
        Ok(())
    }

    /// Start an instance
    #[instrument(skip(self), fields(instance_id = %id))]
    pub async fn start_instance(&self, id: &str) -> Result<()> {
        let mut instances = self.instances.write().await;
        let instance = instances
            .get_mut(id)
            .ok_or_else(|| anyhow::anyhow!("Instance '{}' not found", id))?;

        // Get template for start command
        let templates = self.templates.read().await;
        let template = templates
            .get(&instance.template_id)
            .ok_or_else(|| anyhow::anyhow!("Template '{}' not found", instance.template_id))?;

        // Build and execute start command
        let command = template.build_start_command(instance);
        let pid = self.monitor.start_process_with_port(
            &command,
            instance.working_dir.as_deref(),
            Some(instance.port),
        )?;

        // Update instance state
        instance.status = service::ServiceStatus::Running;
        instance.pid = Some(pid);
        instance.started_at = Some(chrono::Utc::now());

        // Broadcast event
        self.event_bus.send(ServiceEvent::StatusChanged {
            instance_id: id.to_string(),
            status: service::ServiceStatus::Running,
            pid: Some(pid),
        });

        info!(instance_id = %id, pid = %pid, "Instance started");
        Ok(())
    }

    /// Stop an instance
    #[instrument(skip(self), fields(instance_id = %id))]
    pub async fn stop_instance(&self, id: &str) -> Result<()> {
        let mut instances = self.instances.write().await;
        let instance = instances
            .get_mut(id)
            .ok_or_else(|| anyhow::anyhow!("Instance '{}' not found", id))?;

        if instance.status != service::ServiceStatus::Running {
            return Ok(()); // Already stopped
        }

        // Get template for optional custom stop command
        let templates = self.templates.read().await;
        let template = templates.get(&instance.template_id);

        // Stop the process
        if let Some(pid) = instance.pid {
            if let Some(tmpl) = template {
                if let Some(stop_cmd) = &tmpl.stop_command {
                    let cmd = stop_cmd.replace("{pid}", &pid.to_string());
                    self.monitor.execute_command(&cmd)?;
                } else {
                    self.monitor.kill_process(pid)?;
                }
            } else {
                self.monitor.kill_process(pid)?;
            }
        }

        // Update instance state
        instance.status = service::ServiceStatus::Stopped;
        instance.pid = None;
        instance.started_at = None;

        // Broadcast event
        self.event_bus.send(ServiceEvent::StatusChanged {
            instance_id: id.to_string(),
            status: service::ServiceStatus::Stopped,
            pid: None,
        });

        info!(instance_id = %id, "Instance stopped");
        Ok(())
    }

    /// Restart an instance
    pub async fn restart_instance(&self, id: &str) -> Result<()> {
        self.stop_instance(id).await?;
        tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
        self.start_instance(id).await
    }

    /// Clone an instance with different configuration
    pub async fn clone_instance(
        &self,
        source_id: &str,
        mut new_config: service::InstanceConfig,
    ) -> Result<String> {
        let source = self
            .get_instance(source_id)
            .await
            .ok_or_else(|| anyhow::anyhow!("Source instance '{}' not found", source_id))?;

        // Inherit template from source
        new_config.template_id = source.template_id;

        self.create_instance(new_config).await
    }

    // =========================================================================
    // BULK OPERATIONS
    // =========================================================================

    /// Start all instances matching the given tags
    pub async fn start_by_tags(&self, tags: &[&str]) -> Vec<Result<()>> {
        let instances = self.instances.read().await;
        let matching: Vec<_> = instances
            .list()
            .into_iter()
            .filter(|i| tags.iter().any(|t| i.tags.contains(&t.to_string())))
            .map(|i| i.id)
            .collect();
        drop(instances);

        let mut results = Vec::new();
        for id in matching {
            results.push(self.start_instance(&id).await);
        }
        results
    }

    /// Stop all instances matching the given tags
    pub async fn stop_by_tags(&self, tags: &[&str]) -> Vec<Result<()>> {
        let instances = self.instances.read().await;
        let matching: Vec<_> = instances
            .list()
            .into_iter()
            .filter(|i| tags.iter().any(|t| i.tags.contains(&t.to_string())))
            .map(|i| i.id)
            .collect();
        drop(instances);

        let mut results = Vec::new();
        for id in matching {
            results.push(self.stop_instance(&id).await);
        }
        results
    }

    // =========================================================================
    // EVENTS & METRICS
    // =========================================================================

    /// Subscribe to service events
    pub fn subscribe(&self) -> broadcast::Receiver<ServiceEvent> {
        self.event_bus.subscribe()
    }

    /// Get system-wide metrics
    pub fn get_system_metrics(&self) -> metrics::SystemMetrics {
        self.monitor.get_system_metrics()
    }

    /// Get metrics for a specific instance
    pub async fn get_instance_metrics(&self, id: &str) -> Option<metrics::InstanceMetrics> {
        let instances = self.instances.read().await;
        let instance = instances.get(id)?;
        instance
            .pid
            .and_then(|pid| self.monitor.get_process_metrics(pid))
    }
}

#[cfg(test)]
mod tests {
    #[allow(unused_imports)]
    use super::*;

    #[tokio::test]
    async fn test_usm_core_creation() {
        // Test will be implemented with mock config
    }
}
