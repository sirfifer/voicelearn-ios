//! Registries for managing templates and instances

use std::collections::HashMap;

use anyhow::Result;

use super::{ServiceInstance, ServiceStatus, ServiceTemplate};

/// Registry for service templates
#[derive(Debug, Default)]
pub struct TemplateRegistry {
    templates: HashMap<String, ServiceTemplate>,
}

impl TemplateRegistry {
    /// Create a new empty registry
    pub fn new() -> Self {
        Self::default()
    }

    /// Register a new template
    pub fn register(&mut self, template: ServiceTemplate) -> Result<()> {
        if self.templates.contains_key(&template.id) {
            anyhow::bail!("Template '{}' already exists", template.id);
        }

        self.templates.insert(template.id.clone(), template);
        Ok(())
    }

    /// Get a template by ID
    pub fn get(&self, id: &str) -> Option<ServiceTemplate> {
        self.templates.get(id).cloned()
    }

    /// Remove a template by ID
    pub fn remove(&mut self, id: &str) -> Result<()> {
        if self.templates.remove(id).is_none() {
            anyhow::bail!("Template '{}' not found", id);
        }
        Ok(())
    }

    /// List all templates
    pub fn list(&self) -> Vec<ServiceTemplate> {
        self.templates.values().cloned().collect()
    }

    /// Get the number of registered templates
    pub fn len(&self) -> usize {
        self.templates.len()
    }

    /// Check if the registry is empty
    pub fn is_empty(&self) -> bool {
        self.templates.is_empty()
    }

    /// Get all template IDs
    pub fn ids(&self) -> Vec<String> {
        self.templates.keys().cloned().collect()
    }
}

/// Registry for service instances
#[derive(Debug, Default)]
pub struct InstanceRegistry {
    instances: HashMap<String, ServiceInstance>,
}

impl InstanceRegistry {
    /// Create a new empty registry
    pub fn new() -> Self {
        Self::default()
    }

    /// Add a new instance
    pub fn add(&mut self, instance: ServiceInstance) -> Result<()> {
        if self.instances.contains_key(&instance.id) {
            anyhow::bail!("Instance '{}' already exists", instance.id);
        }

        // Check for port conflicts
        if let Some(existing) = self.find_by_port(instance.port) {
            anyhow::bail!(
                "Port {} is already in use by instance '{}'",
                instance.port,
                existing.id
            );
        }

        self.instances.insert(instance.id.clone(), instance);
        Ok(())
    }

    /// Get an instance by ID
    pub fn get(&self, id: &str) -> Option<ServiceInstance> {
        self.instances.get(id).cloned()
    }

    /// Get a mutable reference to an instance by ID
    pub fn get_mut(&mut self, id: &str) -> Option<&mut ServiceInstance> {
        self.instances.get_mut(id)
    }

    /// Remove an instance by ID
    pub fn remove(&mut self, id: &str) -> Result<()> {
        if self.instances.remove(id).is_none() {
            anyhow::bail!("Instance '{}' not found", id);
        }
        Ok(())
    }

    /// List all instances
    pub fn list(&self) -> Vec<ServiceInstance> {
        self.instances.values().cloned().collect()
    }

    /// List instances by template ID
    pub fn list_by_template(&self, template_id: &str) -> Vec<ServiceInstance> {
        self.instances
            .values()
            .filter(|i| i.template_id == template_id)
            .cloned()
            .collect()
    }

    /// List instances by tag
    pub fn list_by_tag(&self, tag: &str) -> Vec<ServiceInstance> {
        self.instances
            .values()
            .filter(|i| i.has_tag(tag))
            .cloned()
            .collect()
    }

    /// List instances by status
    pub fn list_by_status(&self, status: ServiceStatus) -> Vec<ServiceInstance> {
        self.instances
            .values()
            .filter(|i| i.status == status)
            .cloned()
            .collect()
    }

    /// Check if any instances exist for a template
    pub fn has_instances_for_template(&self, template_id: &str) -> bool {
        self.instances
            .values()
            .any(|i| i.template_id == template_id)
    }

    /// Find an instance using a specific port
    pub fn find_by_port(&self, port: u16) -> Option<&ServiceInstance> {
        self.instances.values().find(|i| i.port == port)
    }

    /// Get all used ports
    pub fn used_ports(&self) -> Vec<u16> {
        self.instances.values().map(|i| i.port).collect()
    }

    /// Get the number of instances
    pub fn len(&self) -> usize {
        self.instances.len()
    }

    /// Check if the registry is empty
    pub fn is_empty(&self) -> bool {
        self.instances.is_empty()
    }

    /// Get all instance IDs
    pub fn ids(&self) -> Vec<String> {
        self.instances.keys().cloned().collect()
    }

    /// Get counts by status
    pub fn status_counts(&self) -> HashMap<ServiceStatus, usize> {
        let mut counts = HashMap::new();
        for instance in self.instances.values() {
            *counts.entry(instance.status).or_insert(0) += 1;
        }
        counts
    }

    /// Get instances with auto_start enabled
    pub fn auto_start_instances(&self) -> Vec<ServiceInstance> {
        self.instances
            .values()
            .filter(|i| i.auto_start)
            .cloned()
            .collect()
    }

    /// Update an instance's status
    pub fn update_status(
        &mut self,
        id: &str,
        status: ServiceStatus,
        pid: Option<u32>,
    ) -> Result<()> {
        let instance = self
            .instances
            .get_mut(id)
            .ok_or_else(|| anyhow::anyhow!("Instance '{}' not found", id))?;

        instance.status = status;
        instance.pid = pid;

        if status == ServiceStatus::Running && instance.started_at.is_none() {
            instance.started_at = Some(chrono::Utc::now());
        } else if status != ServiceStatus::Running {
            instance.started_at = None;
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::service::{InstanceConfig, ServiceCategory};

    fn create_test_template(id: &str) -> ServiceTemplate {
        ServiceTemplate {
            id: id.to_string(),
            display_name: format!("Test {}", id),
            description: None,
            default_port: 8000,
            port_range: Some((8000, 8099)),
            start_command: "echo start".to_string(),
            stop_command: None,
            health_endpoint: None,
            health_timeout_ms: 5000,
            category: ServiceCategory::Core,
            supports_multiple: true,
            is_docker: false,
            default_env: Default::default(),
        }
    }

    fn create_test_instance(id: &str, port: u16) -> ServiceInstance {
        ServiceInstance::from_config(InstanceConfig {
            instance_id: id.to_string(),
            template_id: "test".to_string(),
            port: Some(port),
            working_dir: None,
            config_path: None,
            version: None,
            git_branch: None,
            tags: vec!["test".to_string()],
            auto_start: false,
            env_vars: Default::default(),
        })
        .unwrap()
    }

    #[test]
    fn test_template_registry() {
        let mut registry = TemplateRegistry::new();

        // Add template
        registry.register(create_test_template("test1")).unwrap();
        assert_eq!(registry.len(), 1);

        // Get template
        let template = registry.get("test1").unwrap();
        assert_eq!(template.id, "test1");

        // Duplicate should fail
        let result = registry.register(create_test_template("test1"));
        assert!(result.is_err());

        // Remove template
        registry.remove("test1").unwrap();
        assert!(registry.is_empty());
    }

    #[test]
    fn test_instance_registry() {
        let mut registry = InstanceRegistry::new();

        // Add instance
        registry.add(create_test_instance("inst1", 8001)).unwrap();
        assert_eq!(registry.len(), 1);

        // Port conflict should fail
        let result = registry.add(create_test_instance("inst2", 8001));
        assert!(result.is_err());

        // Different port should work
        registry.add(create_test_instance("inst2", 8002)).unwrap();
        assert_eq!(registry.len(), 2);

        // Find by port
        let found = registry.find_by_port(8001).unwrap();
        assert_eq!(found.id, "inst1");

        // Update status
        registry
            .update_status("inst1", ServiceStatus::Running, Some(12345))
            .unwrap();
        let instance = registry.get("inst1").unwrap();
        assert_eq!(instance.status, ServiceStatus::Running);
        assert_eq!(instance.pid, Some(12345));
    }

    #[test]
    fn test_instance_filtering() {
        let mut registry = InstanceRegistry::new();

        let mut inst1 = create_test_instance("inst1", 8001);
        inst1.tags = vec!["production".to_string()];
        inst1.status = ServiceStatus::Running;

        let mut inst2 = create_test_instance("inst2", 8002);
        inst2.tags = vec!["development".to_string()];
        inst2.status = ServiceStatus::Stopped;

        registry.add(inst1).unwrap();
        registry.add(inst2).unwrap();

        // Filter by tag
        let prod = registry.list_by_tag("production");
        assert_eq!(prod.len(), 1);
        assert_eq!(prod[0].id, "inst1");

        // Filter by status
        let running = registry.list_by_status(ServiceStatus::Running);
        assert_eq!(running.len(), 1);
        assert_eq!(running[0].id, "inst1");

        // Status counts
        let counts = registry.status_counts();
        assert_eq!(counts.get(&ServiceStatus::Running), Some(&1));
        assert_eq!(counts.get(&ServiceStatus::Stopped), Some(&1));
    }
}
