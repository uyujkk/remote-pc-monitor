# Changelog

## v1.1.0

- Display CPU, motherboard, GPU, RAM module and physical disk models in the dashboard without collecting serial numbers.
- Store GPU power history and show it in a dedicated trend view. Improve chart scaling, empty states and min/max summaries.
- Modernize the Windows collector window and tray icon; add a persistent Chinese/English language selector.
- Include updated dashboard assets in the existing-deployment upgrade archive and restore them during rollback.
- Clarify that CPU package temperature requires an optional hardware sensor provider such as LibreHardwareMonitor; the collector does not install a kernel driver.

## v1.0.0

- First public source release of the standalone ECS receiver and Windows tray collector.
- Configurable HTTPS deployment origin and certificate paths; collector endpoints read from imported configuration.
- Includes server-side session revocation, request limits, offline pinned dependencies and the existing-install rollback updater.
- Includes the daily verified SQLite backup installer with 14-day retention.
- English installation, usage, TLS, security and development documentation. Application UI remains Chinese.
- Public installable packages rebuilt without personal deployment configuration or credentials.

The running predecessor was validated on Alibaba Cloud Linux 3 and Windows. The generalized public packages have local regression validation; a fresh installation on another host remains a target-environment check.
