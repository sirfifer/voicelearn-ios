//! Event bus for broadcasting events to multiple subscribers

use tokio::sync::broadcast;
use tracing::trace;

use super::ServiceEvent;

/// Event bus for broadcasting service events
///
/// Uses a broadcast channel to allow multiple subscribers to receive
/// events. Subscribers that fall behind will miss events (they won't
/// block the sender).
pub struct EventBus {
    sender: broadcast::Sender<ServiceEvent>,
}

impl EventBus {
    /// Create a new event bus with the specified capacity
    ///
    /// Capacity determines how many events can be buffered before
    /// slow receivers start missing events.
    pub fn new(capacity: usize) -> Self {
        let (sender, _) = broadcast::channel(capacity);
        Self { sender }
    }

    /// Send an event to all subscribers
    ///
    /// Returns the number of receivers that received the event.
    /// Returns 0 if there are no active subscribers.
    pub fn send(&self, event: ServiceEvent) -> usize {
        trace!(event_type = %event.event_type(), "Broadcasting event");
        self.sender.send(event).unwrap_or(0)
    }

    /// Subscribe to events
    ///
    /// Returns a receiver that will get all future events.
    /// If the receiver falls behind, it will receive a `Lagged` error
    /// indicating how many events were missed.
    pub fn subscribe(&self) -> broadcast::Receiver<ServiceEvent> {
        self.sender.subscribe()
    }

    /// Get the current number of active subscribers
    pub fn subscriber_count(&self) -> usize {
        self.sender.receiver_count()
    }
}

impl Default for EventBus {
    fn default() -> Self {
        Self::new(1024)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::service::ServiceStatus;

    #[tokio::test]
    async fn test_event_bus_send_receive() {
        let bus = EventBus::new(16);

        // Subscribe before sending
        let mut rx = bus.subscribe();

        // Send an event
        let event = ServiceEvent::StatusChanged {
            instance_id: "test".to_string(),
            status: ServiceStatus::Running,
            pid: Some(12345),
        };
        let sent = bus.send(event);
        assert_eq!(sent, 1);

        // Receive the event
        let received = rx.recv().await.unwrap();
        match received {
            ServiceEvent::StatusChanged {
                instance_id,
                status,
                pid,
            } => {
                assert_eq!(instance_id, "test");
                assert_eq!(status, ServiceStatus::Running);
                assert_eq!(pid, Some(12345));
            },
            _ => panic!("Wrong event type"),
        }
    }

    #[tokio::test]
    async fn test_multiple_subscribers() {
        let bus = EventBus::new(16);

        let mut rx1 = bus.subscribe();
        let mut rx2 = bus.subscribe();

        assert_eq!(bus.subscriber_count(), 2);

        // Send an event
        let event = ServiceEvent::InstanceCreated {
            instance_id: "test".to_string(),
            template_id: "template".to_string(),
        };
        bus.send(event);

        // Both should receive it
        let e1 = rx1.recv().await.unwrap();
        let e2 = rx2.recv().await.unwrap();

        assert_eq!(e1.event_type(), "instance_created");
        assert_eq!(e2.event_type(), "instance_created");
    }

    #[test]
    fn test_no_subscribers() {
        let bus = EventBus::new(16);

        // Send without subscribers
        let event = ServiceEvent::Error {
            instance_id: None,
            message: "test error".to_string(),
        };
        let sent = bus.send(event);
        assert_eq!(sent, 0);
    }
}
