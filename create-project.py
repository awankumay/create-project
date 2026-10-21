#!/usr/bin/env python3
"""Python launcher for the shared PHP/Laravel installer (Python 3.9+)."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def main():
    if not shutil.which('php'):
        raise SystemExit('PHP CLI 8.4+ is required for the Laravel installer.')
    local = Path(__file__).resolve().parent
    if (local / 'installer/install.php').is_file():
        return subprocess.call(['php', str(local / 'create-project.php'), *sys.argv[1:]])
    if not shutil.which('git'):
        raise SystemExit('Git is required.')
    with tempfile.TemporaryDirectory(prefix='create-project-') as work:
        destination = Path(work) / 'installer'
        subprocess.run(['git', 'clone', '--quiet', '--depth', '1', '--branch',
                        os.environ.get('CREATE_PROJECT_REF', 'main'),
                        'https://github.com/awankumay/create-project.git', str(destination)], check=True)
        return subprocess.call(['php', str(destination / 'create-project.php'), *sys.argv[1:]])


if __name__ == '__main__':
    sys.exit(main())
