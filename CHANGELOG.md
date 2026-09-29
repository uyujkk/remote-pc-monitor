# Changelog

## Unreleased

- Restore the Trends page layout with the live CPU, memory, GPU and download cards above a taller history chart; keep disk and system-detail panels in Hardware.
- Split the GitHub documentation into short English/Chinese quick deployment guides and complete manuals, with a Chinese TLS/renewal guide and clearer paths for fresh installation versus existing-server updates.

## v1.3.0

- Split the dashboard into sidebar modules: Overview, Hardware, Trends, Automation and Results, with a compact mobile module navigation.
- Show AUTO-MAS task scripts individually when a live snapshot is available and keep historical outcomes in the Results module.
- Aggregate seven days of AUTO-MAS history into completed/error totals and up to twelve recent execution results with bounded, filtered excerpts and a last-read timestamp. The v5.4.0 limitation remains explicit: historical outcomes do not reveal current task progress.
- Keep the previous successful history summary in the running collector when the local AUTO-MAS API temporarily becomes unavailable. Existing collectors remain accepted by the updated server.

## v1.2.0

- Refresh the dashboard with a dedicated AUTO-MAS status panel and responsive task cards.
- Add persistent Chinese/English language switching to the web login and dashboard.
- Read AUTO-MAS health and, when available, live task snapshots from the Windows PC's loopback API without changing AUTO-MAS or exposing an inbound port.
- For AUTO-MAS v5.4.0, read only the newest historical `DONE`/`ERROR` result because that release has no live runtime snapshot endpoint. Do not infer current task health from that result.
- Bound and validate all uploaded AUTO-MAS summaries; raw task logs, user data and configuration are not uploaded.

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
