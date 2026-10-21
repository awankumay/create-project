#!/usr/bin/env php
<?php
declare(strict_types=1);
function fail(string $message): never { fwrite(STDERR, "Error: $message\n"); exit(2); }
function usage(): void { echo "php create-project.php NAME [--parent PATH] [--modules core,sales] [--mobile] [--gateway] [--dry-run]\n"; }
$name = null; $parent = getcwd(); $modulesText = 'core,master-data,purchasing,sales,inventory,finance,accounting,printing';
$mobile = false; $gateway = false; $dry = false;
for ($i=1; $i<$argc; $i++) {
    $arg=$argv[$i];
    switch ($arg) {
        case '--help': case '-h': usage(); exit(0);
        case '--parent': case '--modules':
            if (!isset($argv[$i+1]) || str_starts_with($argv[$i+1], '--')) fail("Missing value for $arg");
            $value=$argv[++$i];
            if ($arg==='--parent') $parent=$value; else $modulesText=$value;
            break;
        case '--mobile': $mobile=true; break;
        case '--gateway': $gateway=true; break;
        case '--dry-run': $dry=true; break;
        default:
            if (str_starts_with($arg,'-') || $name!==null) fail("Unknown argument: $arg");
            $name=$arg;
    }
}
$valid=fn(string $s): bool => preg_match('/^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/D', $s)===1;
if ($name===null || !$valid($name)) fail('Provide a lowercase project slug');
if ($parent==='') fail('Parent cannot be empty');
$modules=array_values(array_unique(explode(',', $modulesText)));
foreach ($modules as $m) if (!$valid($m)) fail('Invalid module list');
$target=rtrim($parent, '/\\').DIRECTORY_SEPARATOR.$name;
if (file_exists($target) || is_link($target)) fail('Target already exists');
$templates=json_decode(<<<'TEMPLATES'
{"README.md": "# __PROJECT_NAME__\n\nPlaceholder monorepo, inspired by 134-hris develop.\nNo Laravel/Flutter/Go runtime is installed. Read docs/INSTALL.md.\n", ".gitignore": "**/.env\n**/.env.*\n!**/.env.example\n**/vendor/\n**/node_modules/\n**/build/\n**/.dart_tool/\n**/*.sqlite\n**/*.sqlite-*\n", "AGENTS.md": "# Working agreement\n\nRead README and docs before changes. Inspect real dependencies. Keep business logic in actions/services. Enforce authorization server-side. Use English code identifiers and translated UI labels. Never commit secrets. Complete focused tests and document results. Placeholder folders do not imply implemented features.\n", ".editorconfig": "root = true\n[*]\ncharset = utf-8\nend_of_line = lf\ninsert_final_newline = true\nindent_style = space\nindent_size = 4\n", "infra/README.md": "# Infrastructure\n\nDevelopment Compose belongs here; production configuration belongs in production/. Compose build context should resolve to ../apps/backend. Add persistent volumes and backup/restore procedures before deployment. No deployment configuration is generated.\n", "scripts/README.md": "# Commands\n\nRun backend commands inside apps/backend. Root scripts may dispatch there once a real application is installed. Keep database migrations an explicit operator action.\n", "docs/DEPLOY.md": "# DEPLOY\n\nStatus: placeholder. Record reviewed project-specific requirements here.\n", "docs/API.md": "# API\n\nStatus: placeholder. Record reviewed project-specific requirements here.\n", "docs/SCHEMA.md": "# SCHEMA\n\nStatus: placeholder. Record reviewed project-specific requirements here.\n", "docs/SECURITY.md": "# SECURITY\n\nStatus: placeholder. Record reviewed project-specific requirements here.\n", "docs/DECISIONS.md": "# DECISIONS\n\nStatus: placeholder. Record reviewed project-specific requirements here.\n", "docs/WORKFLOWS.md": "# WORKFLOWS\n\nStatus: placeholder. Record reviewed project-specific requirements here.\n", "docs/TODO.md": "# Backlog\n\n- [ ] INF-001: select clean backend baseline and pin commit\n- [ ] BE-001: install backend and verify boot/auth\n- [ ] BE-002: define module boundaries and permissions\n- [ ] API-001: define API contracts\n- [ ] INF-002: add development Compose\n- [ ] INF-003: add path-aware CI\n- [ ] INF-004: verify backup and restore\n", "docs/DESIGN.md": "# DESIGN\n\nStatus: placeholder. Record reviewed project-specific requirements here.\n", "docs/INSTALL.md": "# Install\n\n1. Install a reviewed starter into a temporary directory outside this project.\n2. Copy application files into apps/backend, retaining its composer.lock, patches and app-modules. Resolve README conflicts manually. Do not overwrite framework files with placeholders.\n3. Run composer install, copy .env.example to .env, configure a development database, then php artisan key:generate inside apps/backend.\n4. Run npm ci and npm run build when a package-lock.json exists.\n5. Review migrations before running php artisan migrate.\n6. Optional mobile: run flutter create in a temporary directory and merge into apps/mobile.\n7. Optional gateway: initialize a Go module with your actual repository module path.\n\nEmpty module directories are NOT Composer packages; do not add modules/* requirements until valid composer.json files and providers exist.\n", "docs/TESTING.md": "# TESTING\n\nStatus: placeholder. Record reviewed project-specific requirements here.\n", "apps/backend/README.md": "# Backend\n\nInstall or copy a reviewed Laravel + Filament starter here. Keep artisan, composer.json, composer.lock, package.json, app-modules, app, routes, patches, Dockerfile and framework configuration together. Do not copy production .env, storage, database dumps or credentials.\n", "packages/api-contracts/README.md": "# API contracts\n\nDefine OpenAPI and integration event schemas here before adding clients. This directory is not an implementation.\n", "docs/STRUCTURE.md": "# Structure\n\napps/backend: Laravel + Filament + ERP modules, one deployable application.\napps/mobile: optional Flutter client, sharing the API contract.\napps/gateway: optional integration service; not required for ordinary ERP.\npackages/api-contracts: OpenAPI and integration schemas.\ninfra/production: deployment definitions, added after runtime selection.\nscripts: root commands dispatching to each application.\ndocs: architecture, decisions, schema, workflows and backlog.\n\nThis generator creates placeholders, not executable frameworks or active Composer packages.\n"}
TEMPLATES, true, 512, JSON_THROW_ON_ERROR);
$files=[];
foreach ($templates as $path=>$content) $files[$path]=str_replace('__PROJECT_NAME__',$name,$content);
$parts=['src/Actions','src/Services','src/Models','src/Policies','src/Filament','database/migrations','database/seeders','resources/views','routes','tests/Feature','tests/Unit'];
$dirs=['infra/production','.github/workflows'];
foreach ($modules as $m) foreach ($parts as $part) $dirs[]="apps/backend/app-modules/$m/$part";
if ($mobile) {
    $files['apps/mobile/README.md']="# Mobile\n\nFlutter placeholder. Initialize the framework separately.\n";
    array_push($dirs,'apps/mobile/lib/core','apps/mobile/lib/features','apps/mobile/test');
}
if ($gateway) {
    $files['apps/gateway/README.md']="# Gateway\n\nOptional integration service placeholder. Select language and protocol first.\n";
    array_push($dirs,'apps/gateway/cmd','apps/gateway/internal','apps/gateway/docs');
}
foreach ($dirs as $d) $files[$d.'/.gitkeep']='';
$files['scaffold.txt']='project='.$name."\nmodules=".implode(',',$modules)."\nmobile=".(int)$mobile."\ngateway=".(int)$gateway."\nkind=placeholder\n";
echo "Target: $target\n";
if ($dry) { ksort($files); foreach (array_keys($files) as $path) echo "$path\n"; exit(0); }
$targetParent=dirname($target);
if (!is_dir($targetParent) && !mkdir($targetParent,0777,true) && !is_dir($targetParent)) fail('Cannot create parent');
if (!mkdir($target,0777,false)) fail('Cannot create target');
foreach ($files as $path=>$content) {
    $destination=$target.DIRECTORY_SEPARATOR.$path;
    $directory=dirname($destination);
    if (!is_dir($directory) && !mkdir($directory,0777,true) && !is_dir($directory)) fail('Cannot create directory');
    if (file_put_contents($destination,$content)===false) fail('Cannot write file');
}
echo "Created placeholder. Frameworks are not installed.\n";
