//! Service management: templates, instances, and registries

mod instance;
mod registry;
mod template;

pub use instance::{InstanceConfig, ServiceInstance, ServiceStatus};
pub use registry::{InstanceRegistry, TemplateRegistry};
pub use template::{ServiceCategory, ServiceTemplate};
