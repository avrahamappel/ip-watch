mod notification;
use notification::notify_ip_changed;

/// Generate a test notification to see how it behaves on the current platform
fn main() {
    notify_ip_changed("TEST", "TEST");
}
