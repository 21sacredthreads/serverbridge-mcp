# Security

This integration grants remote code execution on explicitly configured SSH accounts. Do **not** open a public issue containing credentials, tokens, private keys, vulnerable endpoints, or sensitive logs. Contact the repository maintainer privately for security reports.

Threat model and recommendations:

- OAuth/password login is necessary but not a substitute for SSH account authorization and least privilege.
- Constrain the target account, network egress, authorized keys, firewall rules, and sudo privileges.
- Prompt injection from files, logs, or tool output can cause dangerous actions if the AI client follows untrusted text. Require operator approval of side effects.
- Host-key pinning must be independently verified before first connection.
- The Compose stack does not publish the raw MCP backend; it still uses a mandatory backend bearer token. Docker networking permits outbound access for SSH/TLS; apply host firewall and egress controls if required.
- Do not trust regex-based dangerous-command detection as a complete sandbox.
- Avoid mounting Docker socket, host root directories, or privileged containers.
- Rotate secrets after suspected leaks; do not merely remove them from Git history.