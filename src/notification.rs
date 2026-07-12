use notify_rust::{Notification, Timeout};
use open::that;

/// URL that we want to link to when the IP changes.
const OPENDNS_URL: &str = "https://dashboard.opendns.com/settings";

/// Send a notification with a button that opens the OpenDNS dashboard.
pub fn notify_ip_changed(old: &str, new: &str) {
    let notification = Notification::new()
        .summary("Public IP changed")
        .body(&format!("{old} -> {new}"))
        .icon("network-workgroup")
        .action("open-dns", "Go to OpenDNS settings")
        .hint(notify_rust::Hint::Category("device".into()))
        .timeout(Timeout::Never)
        .show();

    if let Ok(n) = notification {
        // Wait for the user to click the button (blocking call)
        n.wait_for_action(|action| {
            if action == "open-dns" {
                let _ = that(OPENDNS_URL);
            }
        });
    }
}
