use notify_rust::{Notification, Timeout};

// Actions
const OPEN_OPENDNS_SETTINGS: &str = "open-settings";
const CONFIRM_IP_UPDATED: &str = "confirm-ip-updated";

/// Send a notification with a button that opens the OpenDNS dashboard.
pub fn notify_ip_changed(
    old: &str,
    new: &str,
    on_open_dns_settings: impl Fn(),
    on_confirm_ip_updated: impl Fn(),
) {
    let notification = Notification::new()
        .summary("Public IP changed")
        .body(&format!("{old} -> {new}"))
        .icon("network-workgroup")
        .action(OPEN_OPENDNS_SETTINGS, "Go to OpenDNS settings")
        .action(CONFIRM_IP_UPDATED, "Store updated IP")
        .timeout(Timeout::Never)
        .show();

    if let Ok(n) = notification {
        // Wait for the user to click the button (blocking call)
        n.wait_for_action(|action| {
            if action == OPEN_OPENDNS_SETTINGS {
                on_open_dns_settings();
            } else if action == CONFIRM_IP_UPDATED {
                on_confirm_ip_updated();
            }
        });
    }
}
