"""Static release guardrails: no Docker, network, or SSH required."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class ReleaseTests(unittest.TestCase):
    def test_gitignore_covers_local_credentials(self):
        ignore = (ROOT / '.gitignore').read_text()
        for item in ('.env', '.runtime/', 'config/servers.toml'):
            self.assertIn(item, ignore)

    def test_compose_keeps_backend_private(self):
        content = (ROOT / 'compose.yaml').read_text()
        block = content.split('  ssh-mcp:\n', 1)[1].split('\n  auth-proxy:', 1)[0]
        self.assertNotRegex(block, r'(?m)^\s+ports:')
        self.assertIn('SSH_MCP_HTTP_TOKEN:', block)
        self.assertIn('no-new-privileges:true', block)

    def test_examples_contain_no_real_server_domain(self):
        files = ('README.md', 'compose.yaml', '.env.example', 'config/servers.example.toml',
                 'install.sh', 'trust-host.sh', 'check.sh')
        joined = '\n'.join((ROOT / p).read_text() for p in files).lower()
        for value in ('admitmint.com', 'quickidly', 'srv1912679', 'frisco'):
            self.assertNotIn(value, joined)

    def test_safe_start_sequence(self):
        install = (ROOT / 'install.sh').read_text()
        start = (ROOT / 'start.sh').read_text()
        self.assertNotIn('chown -R 1000:1000', install)
        self.assertIn('./check.sh', start)
        self.assertLess(start.index('./check.sh'), start.index('chown -R 1000:1000'))
        self.assertLess(start.index('chown -R 1000:1000'), start.index('docker compose up -d'))

    def test_no_local_secrets_shipped(self):
        for path in ('.env', 'config/servers.toml', '.runtime/ssh/id_ed25519'):
            self.assertFalse((ROOT / path).exists(), path)

if __name__ == '__main__':
    unittest.main()
