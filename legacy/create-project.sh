#!/usr/bin/env bash
# Standalone: Bash 3.2+, mkdir, dirname, sort. No PHP/Python required.
set -euo pipefail
usage() { printf '%s\n' 'bash create-project.sh NAME [--parent PATH] [--modules core,sales] [--mobile] [--gateway] [--dry-run]'; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 2; }
name=''; parent="$PWD"; modules_text='core,master-data,purchasing,sales,inventory,finance,accounting,printing'
mobile=0; gateway=0; dry=0
while (( $# )); do
    case "$1" in
        --help|-h) usage; exit 0 ;;
        --parent|--modules)
            (( $# >= 2 )) || fail "Missing value for $1"
            [[ "$2" != --* && -n "$2" ]] || fail "Missing value for $1"
            if [[ "$1" == --parent ]]; then parent="$2"; else modules_text="$2"; fi
            shift 2 ;;
        --mobile) mobile=1; shift ;;
        --gateway) gateway=1; shift ;;
        --dry-run) dry=1; shift ;;
        -*) fail "Unknown option: $1" ;;
        *) [[ -z "$name" ]] || fail "Unexpected argument: $1"; name="$1"; shift ;;
    esac
done
valid_slug() { [[ "$1" =~ ^[a-z][a-z0-9]*(-[a-z0-9]+)*$ ]]; }
valid_slug "$name" || fail 'Provide a lowercase project slug'
[[ "$modules_text" != ,* && "$modules_text" != *, && "$modules_text" != *,,* ]] || fail 'Invalid module list'
IFS=',' read -r -a raw_modules <<< "$modules_text"
modules=()
for module in "${raw_modules[@]}"; do
    valid_slug "$module" || fail 'Invalid module list'
    found=0
    for existing in "${modules[@]+"${modules[@]}"}"; do
        [[ "$existing" != "$module" ]] || found=1
    done
    if (( found == 0 )); then modules+=("$module"); fi
done
(( ${#modules[@]} )) || fail 'Invalid module list'
# Prefix relative parent paths so utilities never interpret them as options.
case "$parent" in /*) ;; *) parent="$PWD/$parent" ;; esac
target="${parent%/}/$name"
[[ ! -e "$target" && ! -L "$target" ]] || fail 'Target already exists'
printf 'Target: %s\n' "$target"
if (( dry == 0 )); then
    mkdir -p "$parent"
    mkdir "$target" # fails if another process created the target
fi
# In dry-run mode consume heredoc content without writing anything.
paths=()
write_file() {
    local relative="$1" line
    paths+=("$relative")
    if (( dry == 0 )); then
        mkdir -p "$(dirname "$target/$relative")"
        : > "$target/$relative"
        while IFS= read -r line || [[ -n "$line" ]]; do
            line="${line//__PROJECT_NAME__/$name}"
            printf '%s\n' "$line" >> "$target/$relative"
        done
    else
        while IFS= read -r line || [[ -n "$line" ]]; do :; done
    fi
}
write_file 'README.md' <<'SCAFFOLD_TEMPLATE_0'
# __PROJECT_NAME__

Placeholder monorepo, inspired by 134-hris develop.
No Laravel/Flutter/Go runtime is installed. Read docs/INSTALL.md.
SCAFFOLD_TEMPLATE_0
write_file '.gitignore' <<'SCAFFOLD_TEMPLATE_1'
**/.env
**/.env.*
!**/.env.example
**/vendor/
**/node_modules/
**/build/
**/.dart_tool/
**/*.sqlite
**/*.sqlite-*
SCAFFOLD_TEMPLATE_1
write_file 'AGENTS.md' <<'SCAFFOLD_TEMPLATE_2'
# Working agreement

Read README and docs before changes. Inspect real dependencies. Keep business logic in actions/services. Enforce authorization server-side. Use English code identifiers and translated UI labels. Never commit secrets. Complete focused tests and document results. Placeholder folders do not imply implemented features.
SCAFFOLD_TEMPLATE_2
write_file '.editorconfig' <<'SCAFFOLD_TEMPLATE_3'
root = true
[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
indent_style = space
indent_size = 4
SCAFFOLD_TEMPLATE_3
write_file 'infra/README.md' <<'SCAFFOLD_TEMPLATE_4'
# Infrastructure

Development Compose belongs here; production configuration belongs in production/. Compose build context should resolve to ../apps/backend. Add persistent volumes and backup/restore procedures before deployment. No deployment configuration is generated.
SCAFFOLD_TEMPLATE_4
write_file 'scripts/README.md' <<'SCAFFOLD_TEMPLATE_5'
# Commands

Run backend commands inside apps/backend. Root scripts may dispatch there once a real application is installed. Keep database migrations an explicit operator action.
SCAFFOLD_TEMPLATE_5
write_file 'docs/DEPLOY.md' <<'SCAFFOLD_TEMPLATE_6'
# DEPLOY

Status: placeholder. Record reviewed project-specific requirements here.
SCAFFOLD_TEMPLATE_6
write_file 'docs/API.md' <<'SCAFFOLD_TEMPLATE_7'
# API

Status: placeholder. Record reviewed project-specific requirements here.
SCAFFOLD_TEMPLATE_7
write_file 'docs/SCHEMA.md' <<'SCAFFOLD_TEMPLATE_8'
# SCHEMA

Status: placeholder. Record reviewed project-specific requirements here.
SCAFFOLD_TEMPLATE_8
write_file 'docs/SECURITY.md' <<'SCAFFOLD_TEMPLATE_9'
# SECURITY

Status: placeholder. Record reviewed project-specific requirements here.
SCAFFOLD_TEMPLATE_9
write_file 'docs/DECISIONS.md' <<'SCAFFOLD_TEMPLATE_10'
# DECISIONS

Status: placeholder. Record reviewed project-specific requirements here.
SCAFFOLD_TEMPLATE_10
write_file 'docs/WORKFLOWS.md' <<'SCAFFOLD_TEMPLATE_11'
# WORKFLOWS

Status: placeholder. Record reviewed project-specific requirements here.
SCAFFOLD_TEMPLATE_11
write_file 'docs/TODO.md' <<'SCAFFOLD_TEMPLATE_12'
# Backlog

- [ ] INF-001: select clean backend baseline and pin commit
- [ ] BE-001: install backend and verify boot/auth
- [ ] BE-002: define module boundaries and permissions
- [ ] API-001: define API contracts
- [ ] INF-002: add development Compose
- [ ] INF-003: add path-aware CI
- [ ] INF-004: verify backup and restore
SCAFFOLD_TEMPLATE_12
write_file 'docs/DESIGN.md' <<'SCAFFOLD_TEMPLATE_13'
# DESIGN

Status: placeholder. Record reviewed project-specific requirements here.
SCAFFOLD_TEMPLATE_13
write_file 'docs/INSTALL.md' <<'SCAFFOLD_TEMPLATE_14'
# Install

1. Install a reviewed starter into a temporary directory outside this project.
2. Copy application files into apps/backend, retaining its composer.lock, patches and app-modules. Resolve README conflicts manually. Do not overwrite framework files with placeholders.
3. Run composer install, copy .env.example to .env, configure a development database, then php artisan key:generate inside apps/backend.
4. Run npm ci and npm run build when a package-lock.json exists.
5. Review migrations before running php artisan migrate.
6. Optional mobile: run flutter create in a temporary directory and merge into apps/mobile.
7. Optional gateway: initialize a Go module with your actual repository module path.

Empty module directories are NOT Composer packages; do not add modules/* requirements until valid composer.json files and providers exist.
SCAFFOLD_TEMPLATE_14
write_file 'docs/TESTING.md' <<'SCAFFOLD_TEMPLATE_15'
# TESTING

Status: placeholder. Record reviewed project-specific requirements here.
SCAFFOLD_TEMPLATE_15
write_file 'apps/backend/README.md' <<'SCAFFOLD_TEMPLATE_16'
# Backend

Install or copy a reviewed Laravel + Filament starter here. Keep artisan, composer.json, composer.lock, package.json, app-modules, app, routes, patches, Dockerfile and framework configuration together. Do not copy production .env, storage, database dumps or credentials.
SCAFFOLD_TEMPLATE_16
write_file 'packages/api-contracts/README.md' <<'SCAFFOLD_TEMPLATE_17'
# API contracts

Define OpenAPI and integration event schemas here before adding clients. This directory is not an implementation.
SCAFFOLD_TEMPLATE_17
write_file 'docs/STRUCTURE.md' <<'SCAFFOLD_TEMPLATE_18'
# Structure

apps/backend: Laravel + Filament + ERP modules, one deployable application.
apps/mobile: optional Flutter client, sharing the API contract.
apps/gateway: optional integration service; not required for ordinary ERP.
packages/api-contracts: OpenAPI and integration schemas.
infra/production: deployment definitions, added after runtime selection.
scripts: root commands dispatching to each application.
docs: architecture, decisions, schema, workflows and backlog.

This generator creates placeholders, not executable frameworks or active Composer packages.
SCAFFOLD_TEMPLATE_18
if (( mobile )); then
    write_file apps/mobile/README.md <<'MOBILE_TEMPLATE'
# Mobile

Flutter placeholder. Initialize the framework separately.
MOBILE_TEMPLATE
fi
if (( gateway )); then
    write_file apps/gateway/README.md <<'GATEWAY_TEMPLATE'
# Gateway

Optional integration service placeholder. Select language and protocol first.
GATEWAY_TEMPLATE
fi
dirs=('infra/production' '.github/workflows')
parts=('src/Actions' 'src/Services' 'src/Models' 'src/Policies' 'src/Filament' 'database/migrations' 'database/seeders' 'resources/views' 'routes' 'tests/Feature' 'tests/Unit')
for module in "${modules[@]}"; do
    for part in "${parts[@]}"; do dirs+=("apps/backend/app-modules/$module/$part"); done
done
if (( mobile )); then dirs+=('apps/mobile/lib/core' 'apps/mobile/lib/features' 'apps/mobile/test'); fi
if (( gateway )); then dirs+=('apps/gateway/cmd' 'apps/gateway/internal' 'apps/gateway/docs'); fi
for directory in "${dirs[@]}"; do
    paths+=("$directory/.gitkeep")
    if (( dry == 0 )); then mkdir -p "$target/$directory"; : > "$target/$directory/.gitkeep"; fi
done
modules_joined=$(IFS=,; printf '%s' "${modules[*]}")
paths+=('scaffold.txt')
if (( dry )); then
    printf '%s\n' "${paths[@]}" | LC_ALL=C sort
else
    printf 'project=%s\nmodules=%s\nmobile=%s\ngateway=%s\nkind=placeholder\n' "$name" "$modules_joined" "$mobile" "$gateway" > "$target/scaffold.txt"
    printf '%s\n' 'Created placeholder. Frameworks are not installed.'
fi
