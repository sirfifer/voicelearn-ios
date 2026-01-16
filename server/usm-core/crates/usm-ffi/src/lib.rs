//! C FFI bindings for USM Core
//!
//! This crate provides C-compatible exports for integrating USM Core
//! with Swift (macOS), Python, and other languages via FFI.

use std::ffi::{c_char, CStr, CString};
use std::path::Path;
use std::ptr;
use std::sync::Arc;

use libc::c_int;
use tokio::runtime::Runtime;
use tokio::sync::RwLock;

use usm_core::{ServiceStatus, UsmCore};

/// Opaque handle to USM Core instance
pub struct UsmHandle {
    core: Arc<RwLock<UsmCore>>,
    runtime: Runtime,
}

/// C-compatible service info
#[repr(C)]
pub struct CServiceInfo {
    pub id: *mut c_char,
    pub template_id: *mut c_char,
    pub display_name: *mut c_char,
    pub port: u16,
    pub status: c_int, // 0 = stopped, 1 = running, 2 = error
    pub cpu_percent: f64,
    pub memory_mb: u64,
}

/// Array of service info for C
#[repr(C)]
pub struct CServiceArray {
    pub data: *mut CServiceInfo,
    pub len: usize,
    pub capacity: usize,
}

// Status codes for C
const STATUS_STOPPED: c_int = 0;
const STATUS_RUNNING: c_int = 1;
const STATUS_ERROR: c_int = 2;

const STATUS_STARTING: c_int = 3;
const STATUS_STOPPING: c_int = 4;
const STATUS_UNKNOWN: c_int = 5;

fn status_to_int(status: ServiceStatus) -> c_int {
    match status {
        ServiceStatus::Stopped => STATUS_STOPPED,
        ServiceStatus::Running => STATUS_RUNNING,
        ServiceStatus::Error => STATUS_ERROR,
        ServiceStatus::Starting => STATUS_STARTING,
        ServiceStatus::Stopping => STATUS_STOPPING,
        ServiceStatus::Unknown => STATUS_UNKNOWN,
    }
}

/// Create a new USM Core instance
///
/// # Safety
/// `config_path` must be a valid null-terminated C string
#[no_mangle]
pub unsafe extern "C" fn usm_create(config_path: *const c_char) -> *mut UsmHandle {
    if config_path.is_null() {
        return ptr::null_mut();
    }

    let path_str = match CStr::from_ptr(config_path).to_str() {
        Ok(s) => s,
        Err(_) => return ptr::null_mut(),
    };

    let runtime = match Runtime::new() {
        Ok(rt) => rt,
        Err(_) => return ptr::null_mut(),
    };

    let core = runtime.block_on(async { UsmCore::new(Path::new(path_str)).await });

    match core {
        Ok(c) => {
            let handle = Box::new(UsmHandle {
                core: Arc::new(RwLock::new(c)),
                runtime,
            });
            Box::into_raw(handle)
        },
        Err(_) => ptr::null_mut(),
    }
}

/// Destroy a USM Core instance
///
/// # Safety
/// `handle` must be a valid pointer returned by `usm_create`
#[no_mangle]
pub unsafe extern "C" fn usm_destroy(handle: *mut UsmHandle) {
    if !handle.is_null() {
        let _ = Box::from_raw(handle);
    }
}

/// Get all service instances
///
/// # Safety
/// `handle` must be a valid pointer returned by `usm_create`
#[no_mangle]
pub unsafe extern "C" fn usm_get_services(handle: *const UsmHandle) -> *mut CServiceArray {
    if handle.is_null() {
        return ptr::null_mut();
    }

    let handle = &*handle;

    let instances = handle.runtime.block_on(async {
        let core = handle.core.read().await;
        core.list_instances(None).await
    });

    let mut services: Vec<CServiceInfo> = Vec::with_capacity(instances.len());

    for instance in instances {
        let id = CString::new(instance.id.clone()).unwrap_or_default();
        let template_id = CString::new(instance.template_id.clone()).unwrap_or_default();
        let display_name = CString::new(instance.id.clone()).unwrap_or_default();

        services.push(CServiceInfo {
            id: id.into_raw(),
            template_id: template_id.into_raw(),
            display_name: display_name.into_raw(),
            port: instance.port,
            status: status_to_int(instance.status),
            cpu_percent: 0.0, // TODO: Get from metrics
            memory_mb: 0,
        });
    }

    let array = Box::new(CServiceArray {
        len: services.len(),
        capacity: services.capacity(),
        data: if services.is_empty() {
            ptr::null_mut()
        } else {
            let ptr = services.as_mut_ptr();
            std::mem::forget(services);
            ptr
        },
    });

    Box::into_raw(array)
}

/// Free a service array
///
/// # Safety
/// `array` must be a valid pointer returned by `usm_get_services`
#[no_mangle]
pub unsafe extern "C" fn usm_free_services(array: *mut CServiceArray) {
    if array.is_null() {
        return;
    }

    let array = Box::from_raw(array);

    if !array.data.is_null() {
        let services = Vec::from_raw_parts(array.data, array.len, array.capacity);

        for service in services {
            if !service.id.is_null() {
                let _ = CString::from_raw(service.id);
            }
            if !service.template_id.is_null() {
                let _ = CString::from_raw(service.template_id);
            }
            if !service.display_name.is_null() {
                let _ = CString::from_raw(service.display_name);
            }
        }
    }
}

/// Start a service instance
///
/// # Safety
/// `handle` must be valid, `instance_id` must be a null-terminated string
#[no_mangle]
pub unsafe extern "C" fn usm_start_service(
    handle: *mut UsmHandle,
    instance_id: *const c_char,
) -> c_int {
    if handle.is_null() || instance_id.is_null() {
        return -1;
    }

    let handle = &*handle;
    let id = match CStr::from_ptr(instance_id).to_str() {
        Ok(s) => s,
        Err(_) => return -1,
    };

    let result = handle.runtime.block_on(async {
        let core = handle.core.read().await;
        core.start_instance(id).await
    });

    match result {
        Ok(_) => 0,
        Err(_) => -1,
    }
}

/// Stop a service instance
///
/// # Safety
/// `handle` must be valid, `instance_id` must be a null-terminated string
#[no_mangle]
pub unsafe extern "C" fn usm_stop_service(
    handle: *mut UsmHandle,
    instance_id: *const c_char,
) -> c_int {
    if handle.is_null() || instance_id.is_null() {
        return -1;
    }

    let handle = &*handle;
    let id = match CStr::from_ptr(instance_id).to_str() {
        Ok(s) => s,
        Err(_) => return -1,
    };

    let result = handle.runtime.block_on(async {
        let core = handle.core.read().await;
        core.stop_instance(id).await
    });

    match result {
        Ok(_) => 0,
        Err(_) => -1,
    }
}

/// Restart a service instance
///
/// # Safety
/// `handle` must be valid, `instance_id` must be a null-terminated string
#[no_mangle]
pub unsafe extern "C" fn usm_restart_service(
    handle: *mut UsmHandle,
    instance_id: *const c_char,
) -> c_int {
    if handle.is_null() || instance_id.is_null() {
        return -1;
    }

    let handle = &*handle;
    let id = match CStr::from_ptr(instance_id).to_str() {
        Ok(s) => s,
        Err(_) => return -1,
    };

    let result = handle.runtime.block_on(async {
        let core = handle.core.read().await;
        core.restart_instance(id).await
    });

    match result {
        Ok(_) => 0,
        Err(_) => -1,
    }
}

/// Get the server port (for WebSocket connection)
#[no_mangle]
pub extern "C" fn usm_get_server_port() -> u16 {
    8767 // Default USM Core server port
}

/// Get version string
#[no_mangle]
pub extern "C" fn usm_version() -> *const c_char {
    static VERSION: &[u8] = b"0.1.0\0";
    VERSION.as_ptr() as *const c_char
}
