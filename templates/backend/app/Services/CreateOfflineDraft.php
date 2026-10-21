<?php

namespace App\Services;

use App\Models\OfflineDraft;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class CreateOfflineDraft
{
    public function handle(User $user, array $input): array
    {
        // Canonical field ordering; never hash raw JSON ordering or access tokens.
        $payload = [
            'draft_id' => strtolower($input['draft_id']),
            'device_id' => strtolower($input['device_id']),
            'title' => $input['title'],
            'notes' => $input['notes'] ?? null,
        ];
        $hash = hash('sha256', json_encode($payload, JSON_THROW_ON_ERROR));
        $operationId = strtolower($input['operation_id']);

        return DB::transaction(function () use ($user, $payload, $hash, $operationId) {
            // Serialize writes per user. This also prevents late commits creating
            // gaps behind an already issued per-user pull cursor on MySQL.
            User::query()->whereKey($user->id)->lockForUpdate()->firstOrFail();
            $previous = DB::table('sync_operations')->where('user_id', $user->id)
                ->where('operation_id', $operationId)->first();
            if ($previous) {
                abort_unless(hash_equals($previous->request_hash, $hash), 409, 'IDEMPOTENCY_KEY_REUSED');
                return json_decode($previous->result, true, flags: JSON_THROW_ON_ERROR);
            }

            abort_if(OfflineDraft::query()->where('uuid', $payload['draft_id'])->exists(), 409, 'DRAFT_ID_EXISTS');
            $draft = OfflineDraft::query()->create([
                'uuid' => $payload['draft_id'], 'user_id' => $user->id,
                'device_id' => $payload['device_id'], 'title' => $payload['title'], 'notes' => $payload['notes'],
            ]);
            $result = ['draft_id' => $draft->uuid, 'title' => $draft->title, 'notes' => $draft->notes,
                'device_id' => $draft->device_id, 'server_sequence' => $draft->id,
                'created_at' => $draft->created_at->toISOString()];
            DB::table('sync_operations')->insert([
                'user_id' => $user->id, 'operation_id' => $operationId, 'request_hash' => $hash,
                'result' => json_encode($result, JSON_THROW_ON_ERROR), 'created_at' => now(), 'updated_at' => now(),
            ]);
            return $result;
        }, attempts: 3);
    }
}
