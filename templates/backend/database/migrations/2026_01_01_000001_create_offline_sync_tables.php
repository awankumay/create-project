<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', fn (Blueprint $table) => $table->boolean('is_admin')->default(false));
        Schema::create('offline_drafts', function (Blueprint $table) {
            $table->id(); // append-only pull cursor, not a business document number
            $table->uuid('uuid')->unique();
            $table->foreignId('user_id')->constrained();
            $table->uuid('device_id');
            $table->string('title', 120);
            $table->text('notes')->nullable();
            $table->timestamps();
            $table->index(['user_id', 'id']);
        });
        Schema::create('sync_operations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained();
            $table->uuid('operation_id');
            $table->char('request_hash', 64);
            $table->json('result');
            $table->timestamps();
            $table->unique(['user_id', 'operation_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sync_operations');
        Schema::dropIfExists('offline_drafts');
        Schema::table('users', fn (Blueprint $table) => $table->dropColumn('is_admin'));
    }
};
