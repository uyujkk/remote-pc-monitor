# Security

The receiver uses trusted HTTPS behind nginx, a dedicated Unix account, password hashing, hashed upload tokens, origin checks on browser mutations, revocable 12-hour browser sessions, strict cookies, input validation and per-IP rate limits. Imported Windows credentials use the current user's DPAPI context. These controls reduce risk; they do not replace host maintenance or a formal security audit.

- Keep TCP 18081 bound to loopback. Do not expose the SQLite files, backup directory or account configuration through a web server.
- A downloaded `config.json` grants upload access. Generating another configuration rotates that key. Treat account configuration and backup archives as secrets too.
- The public collector accepts any valid HTTPS `/api/ingest` address. Import only configuration from your own receiver.
- Sign-out revokes the current server-side session. The password-reset script rotates the signing secret and invalidates previous browser cookies.
- Keep TLS renewal operational. Do not use `curl -k` or disable collector certificate validation as a workaround.
- Device access allows uploads; it does not grant dashboard read access or remote command execution.
- Backups are root-only but not encrypted at rest. Off-host copying is manual. Disk loss, a root compromise or destructive cloud-account access can still destroy local backups.
- The software does not configure SSH/FRP security, install OS security updates, provide MFA, send failure alerts or protect against volumetric denial of service.

Report suspected vulnerabilities without including live credentials or private logs in a public issue. Use GitHub private vulnerability reporting if the repository has it enabled; otherwise first request a private contact channel without disclosing exploit details.
