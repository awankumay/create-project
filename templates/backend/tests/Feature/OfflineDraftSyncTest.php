<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class OfflineDraftSyncTest extends TestCase
{
    use RefreshDatabase;

    private function payload(): array
    {
        return ['operation_id' => (string) Str::uuid(), 'draft_id' => (string) Str::uuid(),
            'device_id' => (string) Str::uuid(), 'title' => 'Draft lapangan', 'notes' => 'Disimpan offline'];
    }

    private function headers(User $user, array $abilities = ['drafts:read', 'drafts:write']): array
    {
        // Each test request must resolve its bearer token afresh, like a real HTTP request.
        app('auth')->forgetGuards();
        return ['Authorization' => 'Bearer '.$user->createToken('test', $abilities)->plainTextToken];
    }

    public function test_retries_after_a_lost_response_do_not_duplicate_the_draft(): void
    {
        $user = User::factory()->create();
        $headers = $this->headers($user);
        $payload = $this->payload();
        $first = $this->postJson('/api/v1/sync/drafts', $payload, $headers)->assertOk()->json();
        $again = $this->postJson('/api/v1/sync/drafts', array_reverse($payload, true), $headers)->assertOk()->json();
        $this->assertSame($first, $again);
        $this->assertDatabaseCount('offline_drafts', 1);
        $this->assertDatabaseCount('sync_operations', 1);
    }

    public function test_reusing_an_operation_with_different_content_is_rejected(): void
    {
        $user = User::factory()->create();
        $headers = $this->headers($user);
        $payload = $this->payload();
        $this->postJson('/api/v1/sync/drafts', $payload, $headers)->assertOk();
        $payload['title'] = 'Changed after sending';
        $this->postJson('/api/v1/sync/drafts', $payload, $headers)->assertConflict();
        $this->assertDatabaseHas('offline_drafts', ['title' => 'Draft lapangan']);
    }

    public function test_a_second_operation_cannot_overwrite_an_existing_draft(): void
    {
        $headers = $this->headers(User::factory()->create());
        $payload = $this->payload();
        $this->postJson('/api/v1/sync/drafts', $payload, $headers)->assertOk();
        $payload['operation_id'] = (string) Str::uuid();
        $this->postJson('/api/v1/sync/drafts', $payload, $headers)->assertConflict();
        $this->assertDatabaseCount('sync_operations', 1);
    }

    public function test_auth_abilities_validation_and_ownership_are_enforced(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create();
        $this->postJson('/api/v1/sync/drafts', $this->payload())->assertUnauthorized();
        $this->postJson('/api/v1/sync/drafts', $this->payload(), $this->headers($user, ['drafts:read']))->assertForbidden();
        $invalid = $this->payload(); $invalid['title'] = '';
        $this->postJson('/api/v1/sync/drafts', $invalid, $this->headers($user))->assertUnprocessable();
        $payload = $this->payload(); $payload['user_id'] = $other->id;
        $this->postJson('/api/v1/sync/drafts', $payload, $this->headers($user))->assertOk();
        $this->assertDatabaseHas('offline_drafts', ['uuid' => $payload['draft_id'], 'user_id' => $user->id]);
        $this->getJson('/api/v1/sync/drafts', $this->headers($other))->assertOk()->assertJsonCount(0, 'data');
        $page = $this->getJson('/api/v1/sync/drafts', $this->headers($user))->assertOk()->assertJsonCount(1, 'data')->json();
        $this->getJson('/api/v1/sync/drafts?cursor='.$page['next_cursor'], $this->headers($user))->assertOk()->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/sync/drafts?cursor=-1', $this->headers($user))->assertUnprocessable();
    }

    public function test_login_issues_an_expiring_token_and_logout_revokes_it(): void
    {
        $user = User::factory()->create(['password' => 'a-strong-test-password']);
        $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'wrong', 'device_name' => 'test'])->assertUnprocessable();
        $login = $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'a-strong-test-password', 'device_name' => 'test'])->assertOk()->json();
        $this->assertNotEmpty($login['expires_at']);
        $headers = ['Authorization' => 'Bearer '.$login['token']];
        $this->deleteJson('/api/v1/auth/session', [], $headers)->assertNoContent();
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_non_admin_users_cannot_open_the_admin_panel(): void
    {
        $this->actingAs(User::factory()->create())->get('/admin')->assertForbidden();
    }
}
