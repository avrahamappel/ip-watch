use std::fs;
use std::path::PathBuf;
use std::thread;
use std::time::Duration;

use dirs::runtime_dir;
use notify_rust::{Notification, Timeout};
use open::that;

/// URL that returns the public IP as plain text.
const IP_API: &str = "https://api.ipify.org?format=text";

/// URL that we want to link to when the IP changes.
const OPENDNS_URL: &str = "https://dashboard.opendns.com/settings";

/// How often we poll the IP (seconds). 300 s = 5 min.
const POLL_INTERVAL: u64 = 300;

/// File that stores the last seen IP.
fn state_file() -> PathBuf {
    let mut path = runtime_dir().unwrap_or_else(|| PathBuf::from("/tmp"));
    path.push("ip-watch.last");
    path
}

/// Read the previously stored IP (if any).
fn read_last_ip() -> Option<String> {
    fs::read_to_string(state_file()).ok().map(|s| s.trim().to_owned())
}

/// Write the current IP to the state file.
fn write_current_ip(ip: &str) {
    let _ = fs::write(state_file(), ip);
}

/// Retrieve the current public IP using the external service.
fn fetch_current_ip() -> Option<String> {
    let resp = match reqwest::blocking::get(IP_API) {
        Err(e) => {
            eprintln!("{e}");
            return None
        },
        Ok(resp) => resp,
    };
    if resp.status().is_success() {
        resp.text().ok().map(|t| t.trim().to_owned())
    } else {
        None
    }
}

/// Send a notification with a button that opens the OpenDNS dashboard.
fn notify_ip_changed(old: &str, new: &str) {
    let notification = Notification::new()
        .summary("Public IP changed")
        .body(&format!("{old} -> {new}"))
        .icon("network-workgroup")
        .action("default", "Go to OpenDNS settings")
        .hint(notify_rust::Hint::Category("device".into()))
        .timeout(Timeout::Default)
        .show();

    if let Ok(n) = notification {
        // Wait for the user to click the button (blocking call)
        n.wait_for_action(|action| {
            if action == "default" {
                let _ = that(OPENDNS_URL);
            }
        });
    }
}

fn main() {
    // Run the loop in a background thread so the process can be started
    // from a systemd user service without blocking systemd.
    thread::spawn(|| loop {
        match fetch_current_ip() {
            Some(current_ip) => {
                eprintln!("Reported IP is: {current_ip}");
                let last_ip = read_last_ip();
                if let Some(prev) = last_ip && prev != current_ip {
                    // IP changed, notify the user
                    eprintln!("IP changed from previous: {prev}");
                    notify_ip_changed(&prev, &current_ip);
                }
                // Store the newest value for the next iteration
                write_current_ip(&current_ip);
            }
            None => eprintln!("Failed to fetch public IP"),
        }

        thread::sleep(Duration::from_secs(POLL_INTERVAL));
    });

    // Keep the process alive
    loop {
        thread::park();
    }
}
