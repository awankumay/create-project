#!/usr/bin/env python3
"""Create a monorepo placeholder without installing frameworks."""
import argparse
import json
import re
from pathlib import Path

TEMPLATES = json.loads(r'''{"README.md": "# __PROJECT_NAME__\n\nPlaceholder monorepo, inspired by 134-hris develop.\nNo Laravel/Flutter/Go runtime is installed. Read docs/INSTALL.md.\n", ".gitignore": "**/.env\n**/.env.*\n!**/.env.example\n**/vendor/\n**/node_modules/\n**/build/\n**/.dart_tool/\n**/*.sqlite\n**/*.sqlite-*\n", "AGENTS.md": "# Working agreement\n\nRead README and docs before changes. Inspect real dependencies. Keep business logic in actions/services. Enforce authorization server-side. Use English code identifiers and translated UI labels. Never commit secrets. Complete focused tests and document results. Placeholder folders do not imply implemented features.\n", ".editorconfig": "root = true\n[*]\ncharset = utf-8\nend_of_line = lf\ninsert_final_newline = true\nindent_style = space\nindent_size = 4\n", "infra/README.md": "# Infrastructure\n\nDevelopment Compose belongs here; production configuration belongs in production/. Compose build context should resolve to ../apps/backend. Add persistent volumes and backup/restore procedures before deployment. No deployment configuration is generated.\n", "scripts/README.md": "# Commands\n\nRun backend commands inside apps/backend. Root scripts may dispatch there once a real application is installed. Keep database migrations an explicit operator action.\n", "docs/DEPLOY.md": "# DEPLOY\n\nStatus: placeholder. Record reviewed project-specific requirements here.\n", "docs/API.md": "# API\n\nStatus: placeholder. Record reviewed project-specific requirements here.\n", "docs/SCHEMA.md": "# SCHEMA\n\nStatus: placeholder. Record reviewed project-specific requirements here.\n", "docs/SECURITY.md": "# SECURITY\n\nStatus: placeholder. Record reviewed project-specific requirements here.\n", "docs/DECISIONS.md": "# DECISIONS\n\nStatus: placeholder. Record reviewed project-specific requirements here.\n", "docs/WORKFLOWS.md": "# WORKFLOWS\n\nStatus: placeholder. Record reviewed project-specific requirements here.\n", "docs/TODO.md": "# Backlog\n\n- [ ] INF-001: select clean backend baseline and pin commit\n- [ ] BE-001: install backend and verify boot/auth\n- [ ] BE-002: define module boundaries and permissions\n- [ ] API-001: define API contracts\n- [ ] INF-002: add development Compose\n- [ ] INF-003: add path-aware CI\n- [ ] INF-004: verify backup and restore\n", "docs/DESIGN.md": "# DESIGN\n\nStatus: placeholder. Record reviewed project-specific requirements here.\n", "docs/INSTALL.md": "# Install\n\n1. Install a reviewed starter into a temporary directory outside this project.\n2. Copy application files into apps/backend, retaining its composer.lock, patches and app-modules. Resolve README conflicts manually. Do not overwrite framework files with placeholders.\n3. Run composer install, copy .env.example to .env, configure a development database, then php artisan key:generate inside apps/backend.\n4. Run npm ci and npm run build when a package-lock.json exists.\n5. Review migrations before running php artisan migrate.\n6. Optional mobile: run flutter create in a temporary directory and merge into apps/mobile.\n7. Optional gateway: initialize a Go module with your actual repository module path.\n\nEmpty module directories are NOT Composer packages; do not add modules/* requirements until valid composer.json files and providers exist.\n", "docs/TESTING.md": "# TESTING\n\nStatus: placeholder. Record reviewed project-specific requirements here.\n", "apps/backend/README.md": "# Backend\n\nInstall or copy a reviewed Laravel + Filament starter here. Keep artisan, composer.json, composer.lock, package.json, app-modules, app, routes, patches, Dockerfile and framework configuration together. Do not copy production .env, storage, database dumps or credentials.\n", "packages/api-contracts/README.md": "# API contracts\n\nDefine OpenAPI and integration event schemas here before adding clients. This directory is not an implementation.\n", "docs/STRUCTURE.md": "# Structure\n\napps/backend: Laravel + Filament + ERP modules, one deployable application.\napps/mobile: optional Flutter client, sharing the API contract.\napps/gateway: optional integration service; not required for ordinary ERP.\npackages/api-contracts: OpenAPI and integration schemas.\ninfra/production: deployment definitions, added after runtime selection.\nscripts: root commands dispatching to each application.\ndocs: architecture, decisions, schema, workflows and backlog.\n\nThis generator creates placeholders, not executable frameworks or active Composer packages.\n"}''')
PARTS = ['src/Actions', 'src/Services', 'src/Models', 'src/Policies', 'src/Filament', 'database/migrations', 'database/seeders', 'resources/views', 'routes', 'tests/Feature', 'tests/Unit']

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('name')
    p.add_argument('--parent', type=Path, default=Path.cwd())
    p.add_argument('--modules', default='core,master-data,purchasing,sales,inventory,finance,accounting,printing')
    p.add_argument('--mobile', action='store_true')
    p.add_argument('--gateway', action='store_true')
    p.add_argument('--dry-run', action='store_true')
    a = p.parse_args()
    valid = lambda s: re.fullmatch(r'[a-z][a-z0-9]*(?:-[a-z0-9]+)*', s)
    if not valid(a.name): p.error('Invalid project slug')
    modules = list(dict.fromkeys(a.modules.split(',')))
    if any(not valid(m) for m in modules): p.error('Invalid module list')
    target = a.parent.resolve() / a.name
    if target.exists() or target.is_symlink(): p.error('Target already exists')
    files = {k:v.replace('__PROJECT_NAME__', a.name) for k,v in TEMPLATES.items()}
    dirs = ['infra/production', '.github/workflows']
    dirs += [f'apps/backend/app-modules/{m}/{part}' for m in modules for part in PARTS]
    if a.mobile:
        files['apps/mobile/README.md'] = '# Mobile\n\nFlutter placeholder. Initialize the framework separately.\n'
        dirs += ['apps/mobile/lib/core', 'apps/mobile/lib/features', 'apps/mobile/test']
    if a.gateway:
        files['apps/gateway/README.md'] = '# Gateway\n\nOptional integration service placeholder. Select language and protocol first.\n'
        dirs += ['apps/gateway/cmd', 'apps/gateway/internal', 'apps/gateway/docs']
    for d in dirs: files[d+'/.gitkeep'] = ''
    files['scaffold.txt'] = f'project={a.name}\nmodules={",".join(modules)}\nmobile={int(a.mobile)}\ngateway={int(a.gateway)}\nkind=placeholder\n'
    print(f'Target: {target}')
    if a.dry_run:
        for k in sorted(files): print(k)
        return
    target.mkdir(parents=True, exist_ok=False)
    for k,v in files.items():
        path = target/k
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open('w', encoding='utf-8', newline='\n') as stream: stream.write(v)
    print('Created placeholder. Frameworks are not installed.')

if __name__ == '__main__':
    main()
