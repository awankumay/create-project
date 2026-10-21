<?php

use App\Http\Controllers\Api\DraftSyncController;
use App\Http\Controllers\Api\SessionController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::post('auth/login', [SessionController::class, 'store'])->middleware('throttle:5,1');
    Route::middleware(['auth:sanctum', 'throttle:120,1'])->group(function () {
        Route::delete('auth/session', [SessionController::class, 'destroy']);
        Route::post('sync/drafts', [DraftSyncController::class, 'store']);
        Route::get('sync/drafts', [DraftSyncController::class, 'index']);
    });
});
