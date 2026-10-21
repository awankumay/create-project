<?php

declare(strict_types=1);

// Single implementation shared by the Bash, PHP and Python launchers.
const LARAVEL_SOURCE_SHA = '9ffef3bc4241e3cc333ef267258a404d0d95f194';

function runCommand(array $arguments, ?string $directory = null): void
{
    echo '+ '.implode(' ', array_map(fn ($value) => escapeshellarg((string) $value), $arguments)).PHP_EOL;
    $command = PHP_OS_FAMILY === 'Windows'
        ? implode(' ', array_map(fn ($value) => escapeshellarg((string) $value), $arguments))
        : $arguments;
    $process = proc_open($command, [0 => STDIN, 1 => STDOUT, 2 => STDERR], $pipes, $directory);
    if (!is_resource($process) || proc_close($process) !== 0) {
        throw new RuntimeException('Command failed. See output above.');
    }
}

function removeTree(string $path): void
{
    if (is_link($path) || is_file($path)) {
        if (!is_link($path)) { @chmod($path, 0666); } // Git object files may be read-only on Windows.
        unlink($path); return;
    }
    foreach (new FilesystemIterator($path) as $item) { removeTree($item->getPathname()); }
    rmdir($path);
}

function copyTemplate(string $source, string $target, string $project): void
{
    if (!is_dir($target)) { mkdir($target, 0777, true); }
    foreach (new FilesystemIterator($source) as $item) {
        $destination = $target.DIRECTORY_SEPARATOR.$item->getFilename();
        if ($item->isDir()) { copyTemplate($item->getPathname(), $destination, $project); }
        else {
            $content = str_replace('__PROJECT_NAME__', $project, file_get_contents($item->getPathname()));
            if (file_put_contents($destination, $content) === false) { throw new RuntimeException('Cannot write '.$destination); }
        }
    }
}

function executableExists(string $command): bool
{
    foreach (explode(PATH_SEPARATOR, (string) getenv('PATH')) as $directory) {
        foreach (PHP_OS_FAMILY === 'Windows' ? ['', '.exe', '.bat', '.cmd'] : [''] as $suffix) {
            if (is_file($directory.DIRECTORY_SEPARATOR.$command.$suffix)) { return true; }
        }
    }
    return false;
}

function installerCommit(): string
{
    $directory = dirname(__DIR__).'/.git';
    if (!is_file($directory.'/HEAD')) { return ''; }
    $head = trim(file_get_contents($directory.'/HEAD'));
    if (preg_match('/^[a-f0-9]{40}$/D', $head)) { return $head; }
    if (!str_starts_with($head, 'ref: ')) { return ''; }
    $reference = substr($head, 5);
    if (is_file($directory.'/'.$reference)) { return trim(file_get_contents($directory.'/'.$reference)); }
    if (is_file($directory.'/packed-refs')) {
        foreach (file($directory.'/packed-refs', FILE_IGNORE_NEW_LINES) as $line) {
            if (str_ends_with($line, ' '.$reference)) { return substr($line, 0, 40); }
        }
    }
    return '';
}

function installProject(array $arguments): int
{
    $options = ['name' => null, 'parent' => getcwd(), 'preset' => 'laravel-offline', 'skip-install' => false, 'dry-run' => false];
    for ($i = 1; $i < count($arguments); $i++) {
        $arg = $arguments[$i];
        if (in_array($arg, ['--help', '-h'], true)) {
            echo "create-project NAME [--preset laravel-offline|laravel-admin] [--parent PATH] [--skip-install] [--dry-run]\n";
            return 0;
        }
        if (in_array($arg, ['--dry-run', '--skip-install'], true)) { $options[substr($arg, 2)] = true; continue; }
        if ($arg === '--mobile') { $options['preset'] = 'laravel-offline'; continue; }
        if (in_array($arg, ['--parent', '--preset'], true)) {
            if (!isset($arguments[$i+1]) || str_starts_with($arguments[$i+1], '--')) { throw new InvalidArgumentException('Missing value for '.$arg); }
            $options[substr($arg, 2)] = $arguments[++$i]; continue;
        }
        if (str_starts_with($arg, '-') || $options['name'] !== null) { throw new InvalidArgumentException('Unknown argument: '.$arg); }
        $options['name'] = $arg;
    }
    $name = $options['name'];
    if (!$name || !preg_match('/^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/D', $name)) { throw new InvalidArgumentException('Use a lowercase project slug, e.g. mitra-business'); }
    if (!in_array($options['preset'], ['laravel-offline', 'laravel-admin'], true)) { throw new InvalidArgumentException('Unknown preset'); }
    if ($options['parent'] === '') { throw new InvalidArgumentException('Parent cannot be empty'); }
    $parent = $options['parent'];
    if (!preg_match('~^(?:/|[a-zA-Z]:[/\\\\]|\\\\\\\\)~', $parent)) { $parent = getcwd().DIRECTORY_SEPARATOR.$parent; }
    $target = rtrim($parent, '/\\').DIRECTORY_SEPARATOR.$name;
    if (file_exists($target) || is_link($target)) { throw new RuntimeException('Target already exists: '.$target); }
    $mobile = $options['preset'] === 'laravel-offline';
    echo "Project: $target\nPreset: {$options['preset']}\nLaravel source: ".LARAVEL_SOURCE_SHA."\n";
    if ($options['dry-run']) {
        echo "Plan: official Laravel 13 source + Filament 5 + Sanctum + draft sync API.\n";
        if ($mobile) { echo "Plan: flutter create (Android/Windows) + Drift outbox + draft UI + sync tests.\n"; }
        echo $options['skip-install'] ? "Dependencies will NOT be installed.\n" : "Dependencies, SQLite demo migrations and focused tests will run. No default account is created.\n";
        return 0;
    }
    if (version_compare(PHP_VERSION, '8.4.0', '<')) { throw new RuntimeException('PHP 8.4+ required'); }
    $required = ['git'];
    if (!$options['skip-install']) {
        foreach (['curl', 'dom', 'fileinfo', 'intl', 'mbstring', 'openssl', 'pdo_sqlite', 'tokenizer', 'xml'] as $extension) {
            if (!extension_loaded($extension)) { throw new RuntimeException('Missing PHP extension: '.$extension); }
        }
    }
    if (!$options['skip-install']) { $required[] = 'composer'; }
    if ($mobile) { $required[] = 'flutter'; }
    foreach ($required as $binary) { if (!executableExists($binary)) { throw new RuntimeException("Missing dependency: $binary"); } }
    if (!is_dir($parent) && !mkdir($parent, 0777, true)) { throw new RuntimeException('Cannot create parent'); }
    $stage = $parent.DIRECTORY_SEPARATOR.'.'.$name.'-install-'.bin2hex(random_bytes(5));
    if (!mkdir($stage, 0777)) { throw new RuntimeException('Cannot create staging directory'); }
    echo "Staging: $stage\n";
    try {
        $backend = $stage.'/apps/backend';
        mkdir($backend, 0777, true);
        runCommand(['git', 'init', '--quiet'], $backend);
        runCommand(['git', 'remote', 'add', 'origin', 'https://github.com/laravel/laravel.git'], $backend);
        runCommand(['git', 'fetch', '--quiet', '--depth', '1', 'origin', LARAVEL_SOURCE_SHA], $backend);
        runCommand(['git', 'checkout', '--quiet', '--detach', 'FETCH_HEAD'], $backend);
        removeTree($backend.'/.git');
        $composer = json_decode(file_get_contents($backend.'/composer.json'), true, flags: JSON_THROW_ON_ERROR);
        $composer['name'] = 'starter/'.$name;
        $composer['require']['php'] = '^8.4';
        $composer['require']['filament/filament'] = '^5.0';
        $composer['require']['laravel/sanctum'] = '^4.3';
        // Setup is explicit: never run the skeleton's post-create migration hook.
        unset($composer['scripts']['post-create-project-cmd'], $composer['scripts']['setup']);
        file_put_contents($backend.'/composer.json', json_encode($composer, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)."\n");
        copyTemplate(dirname(__DIR__).'/templates/backend', $backend, $name);
        copyTemplate(dirname(__DIR__).'/templates/project', $stage, $name);
        $env = file_get_contents($backend.'/.env.example');
        foreach (['APP_NAME' => $name, 'APP_ENV' => 'local', 'APP_DEBUG' => 'true', 'DB_CONNECTION' => 'sqlite'] as $key => $value) {
            $env = preg_replace('/^'.$key.'=.*$/m', $key.'='.$value, $env);
        }
        $env = preg_replace('/^DB_DATABASE=.*$/m', 'DB_DATABASE=database/database.sqlite', $env);
        // SQLite defaults to database/database.sqlite when DB_DATABASE is absent.
        file_put_contents($backend.'/.env', $env);
        touch($backend.'/database/database.sqlite');
        if ($mobile) {
            $client = $stage.'/apps/client';
            runCommand(['flutter', 'create', '--no-pub', '--platforms=android,windows', '--org', 'com.example', '--project-name', str_replace('-', '_', $name), $client], $stage);
            copyTemplate(dirname(__DIR__).'/templates/client', $client, str_replace('-', '_', $name));
            $manifest = $client.'/android/app/src/main/AndroidManifest.xml';
            $xml = file_get_contents($manifest);
            if (!str_contains($xml, 'android.permission.INTERNET')) {
                $xml = preg_replace('/(<manifest[^>]*>)/', '$1'."\n    <uses-permission android:name=\"android.permission.INTERNET\"/>", $xml, 1);
                file_put_contents($manifest, $xml);
            }
            @unlink($client.'/test/widget_test.dart'); // generated counter-app test no longer applies
        }
        file_put_contents($stage.'/starter-source.json', json_encode([
            'preset' => $options['preset'], 'laravel_skeleton_commit' => LARAVEL_SOURCE_SHA,
            'installer_commit' => installerCommit(),
            'dependencies_installed' => !$options['skip-install'],
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)."\n");
        if (!$options['skip-install']) {
            runCommand(['composer', 'install', '--no-interaction', '--prefer-dist'], $backend);
            runCommand([PHP_BINARY, 'artisan', 'key:generate', '--no-interaction'], $backend);
            runCommand([PHP_BINARY, 'artisan', 'filament:assets'], $backend);
            // This is a freshly created local SQLite demo only, not a production DB.
            runCommand([PHP_BINARY, 'artisan', 'migrate', '--no-interaction'], $backend);
            runCommand([PHP_BINARY, 'artisan', 'test', '--compact', '--filter=OfflineDraftSyncTest'], $backend);
            if ($mobile) {
                runCommand(['flutter', 'pub', 'get'], $stage.'/apps/client');
                runCommand(['dart', 'run', 'build_runner', 'build'], $stage.'/apps/client');
                runCommand(['dart', 'format', 'lib', 'test'], $stage.'/apps/client');
                runCommand(['flutter', 'analyze'], $stage.'/apps/client');
                runCommand(['flutter', 'test'], $stage.'/apps/client');
            }
        }
        if (file_exists($target) || is_link($target)) { throw new RuntimeException('Target appeared during installation; refusing overwrite'); }
        if (!rename($stage, $target)) { throw new RuntimeException('Cannot move staged project'); }
    } catch (Throwable $exception) {
        // Keep failed staging output for inspection; never delete user data automatically.
        throw new RuntimeException($exception->getMessage()."\nIncomplete staging kept at: $stage", 0, $exception);
    }
    echo "\nCreated: $target\nRead README.md for account creation, LAN/API URL setup, and offline test steps.\n";
    if ($options['skip-install']) { echo "Dependencies and code generation were skipped. Run the documented setup before use.\n"; }
    return 0;
}
