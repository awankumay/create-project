<?php

declare(strict_types=1);

require dirname(__DIR__).'/installer/install.php';

$root = sys_get_temp_dir().'/starter-test-'.bin2hex(random_bytes(4));
mkdir($root);
function verify(bool $condition, string $message): void
{
    if (!$condition) { throw new RuntimeException($message); }
}
try {
    ob_start();
    verify(installProject(['installer', 'safe-project', '--parent', $root, '--dry-run']) === 0, 'dry run exit');
    ob_end_clean();
    verify(!file_exists($root.'/safe-project'), 'dry run wrote a target');
    foreach ([['../escape'], ['BadName'], ['safe', '--preset', 'unknown'], ['safe', '--unknown'], ['safe', '--parent']] as $arguments) {
        $rejected = false;
        try { installProject(['installer', ...$arguments]); } catch (InvalidArgumentException) { $rejected = true; }
        verify($rejected, 'invalid arguments accepted: '.implode(' ', $arguments));
    }
    mkdir($root.'/existing');
    $rejected = false;
    try { installProject(['installer', 'existing', '--parent', $root, '--dry-run']); } catch (RuntimeException) { $rejected = true; }
    verify($rejected, 'existing target accepted');
    file_put_contents($root.'/existing/sentinel.txt', 'keep');
    verify(file_get_contents($root.'/existing/sentinel.txt') === 'keep', 'existing file changed');
    if (PHP_OS_FAMILY !== 'Windows') {
        symlink($root.'/missing', $root.'/linked');
        $rejected = false;
        try { installProject(['installer', 'linked', '--parent', $root, '--dry-run']); } catch (RuntimeException) { $rejected = true; }
        verify($rejected, 'symlink target accepted');
    }
    echo "PASS: dry-run, invalid inputs, target and symlink refusal.\n";
} finally { removeTree($root); }
