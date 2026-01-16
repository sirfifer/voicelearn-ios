//! USM Core Command-Line Interface
//!
//! A CLI tool for managing services through USM Core.

use std::path::PathBuf;

use clap::{Parser, Subcommand};
use tracing::info;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

use usm_core::{InstanceConfig, ServiceStatus, UsmCore};

#[derive(Parser)]
#[command(name = "usm")]
#[command(author, version, about = "USM Core - Universal Service Manager", long_about = None)]
struct Cli {
    /// Path to the configuration file
    #[arg(short, long, default_value = "config/services.toml")]
    config: PathBuf,

    /// Enable verbose output
    #[arg(short, long)]
    verbose: bool,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Start the USM Core server
    Server {
        /// Port to listen on
        #[arg(short, long, default_value = "8767")]
        port: u16,
    },

    /// List all templates
    Templates,

    /// List all instances
    Instances {
        /// Filter by template ID
        #[arg(short, long)]
        template: Option<String>,

        /// Filter by tag
        #[arg(long)]
        tag: Option<String>,

        /// Filter by status (running, stopped, error)
        #[arg(short, long)]
        status: Option<String>,
    },

    /// Start a service instance
    Start {
        /// Instance ID to start
        instance_id: String,
    },

    /// Stop a service instance
    Stop {
        /// Instance ID to stop
        instance_id: String,
    },

    /// Restart a service instance
    Restart {
        /// Instance ID to restart
        instance_id: String,
    },

    /// Show system and instance metrics
    Metrics {
        /// Instance ID (optional, shows system metrics if not specified)
        instance_id: Option<String>,
    },

    /// Create a new instance from a template
    Create {
        /// Template ID to use
        #[arg(short, long)]
        template: String,

        /// Instance ID (auto-generated if not specified)
        #[arg(short, long)]
        id: Option<String>,

        /// Port to use (uses template default if not specified)
        #[arg(short, long)]
        port: Option<u16>,

        /// Tags (comma-separated)
        #[arg(long)]
        tags: Option<String>,

        /// Auto-start the instance
        #[arg(long)]
        auto_start: bool,
    },

    /// Remove an instance
    Remove {
        /// Instance ID to remove
        instance_id: String,

        /// Force removal even if running
        #[arg(short, long)]
        force: bool,
    },

    /// Start all instances matching criteria
    StartAll {
        /// Filter by tag
        #[arg(long)]
        tag: Option<String>,
    },

    /// Stop all instances matching criteria
    StopAll {
        /// Filter by tag
        #[arg(long)]
        tag: Option<String>,
    },
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();

    // Initialize logging
    let filter = if cli.verbose { "debug" } else { "info" };
    tracing_subscriber::registry()
        .with(tracing_subscriber::fmt::layer())
        .with(tracing_subscriber::EnvFilter::new(filter))
        .init();

    // Load USM Core
    let core = UsmCore::new(&cli.config).await?;

    match cli.command {
        Commands::Server { port } => {
            info!(port = port, "Starting USM Core server");
            core.start_server(port).await?;
        },

        Commands::Templates => {
            let templates = core.list_templates().await;
            if templates.is_empty() {
                println!("No templates registered.");
            } else {
                println!(
                    "{:<20} {:<30} {:<10} {:<10}",
                    "ID", "Name", "Port", "Multiple"
                );
                println!("{}", "-".repeat(70));
                for t in templates {
                    println!(
                        "{:<20} {:<30} {:<10} {:<10}",
                        t.id,
                        t.display_name,
                        t.default_port,
                        if t.supports_multiple { "Yes" } else { "No" }
                    );
                }
            }
        },

        Commands::Instances {
            template,
            tag,
            status,
        } => {
            let instances = core.list_instances(template.as_deref()).await;

            let filtered: Vec<_> = instances
                .into_iter()
                .filter(|i| {
                    if let Some(ref t) = tag {
                        if !i.has_tag(t) {
                            return false;
                        }
                    }
                    if let Some(ref s) = status {
                        let status_match = match s.as_str() {
                            "running" => i.status == ServiceStatus::Running,
                            "stopped" => i.status == ServiceStatus::Stopped,
                            "error" => i.status == ServiceStatus::Error,
                            _ => true,
                        };
                        if !status_match {
                            return false;
                        }
                    }
                    true
                })
                .collect();

            if filtered.is_empty() {
                println!("No instances found.");
            } else {
                println!(
                    "{:<25} {:<20} {:<8} {:<10} {:<20}",
                    "ID", "Template", "Port", "Status", "Tags"
                );
                println!("{}", "-".repeat(85));
                for i in filtered {
                    let status = match i.status {
                        ServiceStatus::Running => "Running",
                        ServiceStatus::Stopped => "Stopped",
                        ServiceStatus::Error => "Error",
                        _ => "Unknown",
                    };
                    println!(
                        "{:<25} {:<20} {:<8} {:<10} {:<20}",
                        i.id,
                        i.template_id,
                        i.port,
                        status,
                        i.tags.join(", ")
                    );
                }
            }
        },

        Commands::Start { instance_id } => {
            info!(instance = %instance_id, "Starting instance");
            core.start_instance(&instance_id).await?;
            println!("Started instance: {}", instance_id);
        },

        Commands::Stop { instance_id } => {
            info!(instance = %instance_id, "Stopping instance");
            core.stop_instance(&instance_id).await?;
            println!("Stopped instance: {}", instance_id);
        },

        Commands::Restart { instance_id } => {
            info!(instance = %instance_id, "Restarting instance");
            core.restart_instance(&instance_id).await?;
            println!("Restarted instance: {}", instance_id);
        },

        Commands::Metrics { instance_id } => {
            if let Some(id) = instance_id {
                if let Some(metrics) = core.get_instance_metrics(&id).await {
                    println!("Instance: {}", id);
                    println!("  CPU: {:.1}%", metrics.cpu_percent);
                    println!("  Memory: {} MB", metrics.memory_bytes / 1024 / 1024);
                    println!("  Threads: {}", metrics.threads);
                } else {
                    println!("No metrics available for instance: {}", id);
                }
            } else {
                let metrics = core.get_system_metrics();
                println!("System Metrics:");
                println!("  CPU: {:.1}%", metrics.cpu_percent);
                println!(
                    "  Memory: {:.2} GB / {:.2} GB ({:.1}%)",
                    metrics.memory_used_gb(),
                    metrics.memory_total_gb(),
                    metrics.memory_percent
                );
            }
        },

        Commands::Create {
            template,
            id,
            port,
            tags,
            auto_start,
        } => {
            let instance_id =
                id.unwrap_or_else(|| format!("{}-{}", template, chrono::Utc::now().timestamp()));

            let tag_vec: Vec<String> = tags
                .map(|t| t.split(',').map(|s| s.trim().to_string()).collect())
                .unwrap_or_default();

            let config = InstanceConfig {
                instance_id: instance_id.clone(),
                template_id: template,
                port,
                working_dir: None,
                config_path: None,
                version: None,
                git_branch: None,
                tags: tag_vec,
                auto_start,
                env_vars: Default::default(),
            };

            let created_id = core.create_instance(config).await?;
            println!("Created instance: {}", created_id);
        },

        Commands::Remove { instance_id, force } => {
            if force {
                // Stop first if running
                let _ = core.stop_instance(&instance_id).await;
            }
            core.remove_instance(&instance_id).await?;
            println!("Removed instance: {}", instance_id);
        },

        Commands::StartAll { tag } => {
            let tags: Vec<&str> = tag.as_deref().map(|t| vec![t]).unwrap_or_default();
            let results = core.start_by_tags(&tags).await;
            let success = results.iter().filter(|r| r.is_ok()).count();
            let failed = results.len() - success;
            println!("Started {} instances ({} failed)", success, failed);
        },

        Commands::StopAll { tag } => {
            let tags: Vec<&str> = tag.as_deref().map(|t| vec![t]).unwrap_or_default();
            let results = core.stop_by_tags(&tags).await;
            let success = results.iter().filter(|r| r.is_ok()).count();
            let failed = results.len() - success;
            println!("Stopped {} instances ({} failed)", success, failed);
        },
    }

    Ok(())
}
