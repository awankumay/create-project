<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\OfflineDraft;
use App\Services\CreateOfflineDraft;
use Illuminate\Http\Request;

class DraftSyncController extends Controller
{
    public function store(Request $request, CreateOfflineDraft $action)
    {
        abort_unless($request->user()->tokenCan('drafts:write'), 403);
        $data = $request->validate([
            'operation_id' => 'required|uuid', 'draft_id' => 'required|uuid',
            'device_id' => 'required|uuid', 'title' => 'required|string|max:120', 'notes' => 'nullable|string|max:2000',
        ]);
        return response()->json(['data' => $action->handle($request->user(), $data)]);
    }

    public function index(Request $request)
    {
        abort_unless($request->user()->tokenCan('drafts:read'), 403);
        $data = $request->validate(['cursor' => 'sometimes|integer|min:0']);
        $cursor = (int) ($data['cursor'] ?? 0);
        $rows = OfflineDraft::query()->where('user_id', $request->user()->id)->where('id', '>', $cursor)
            ->orderBy('id')->limit(101)->get();
        $page = $rows->take(100);
        return response()->json(['data' => $page->map(fn ($draft) => [
            'draft_id' => $draft->uuid, 'title' => $draft->title, 'notes' => $draft->notes,
            'device_id' => $draft->device_id, 'server_sequence' => $draft->id,
            'created_at' => $draft->created_at->toISOString(),
        ])->values(), 'next_cursor' => $page->last()?->id ?? $cursor, 'has_more' => $rows->count() > 100]);
    }
}
