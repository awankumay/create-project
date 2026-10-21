#!/usr/bin/env php
<?php

declare(strict_types=1);

// Native PHP entry point. Run from a cloned/downloaded installer repository.
try {
    if (!is_file(__DIR__.'/installer/install.php')) {
        throw new RuntimeException('Download/clone the complete create-project repository, or use the Bash URL launcher.');
    }
    require __DIR__.'/installer/install.php';
    exit(installProject($argv));
} catch (Throwable $exception) {
    fwrite(STDERR, 'Error: '.$exception->getMessage().PHP_EOL);
    exit(1);
}
