# Third-party components

This project uses React, React DOM, Recharts, Lucide React and esbuild for its frontend, and Flask, Werkzeug, Gunicorn, Blinker, Click, ItsDangerous, Jinja2, MarkupSafe and Packaging for its receiver. They retain their respective upstream licenses and copyright notices.

Python release wheels include their upstream `.dist-info` metadata and license files. The browser build preserves dependency legal comments in `app.js.LEGAL.txt`, shipped with the static assets. Refer to the exact locked dependency version's package metadata for its full terms. No ownership of upstream components is claimed.

Windows PowerShell, nginx, systemd, Certbot and optional NVIDIA/LibreHardwareMonitor tools are separate prerequisites, not bundled proprietary software. Optional sensor tools are not automatically installed.
