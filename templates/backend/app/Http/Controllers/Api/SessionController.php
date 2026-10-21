<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class SessionController extends Controller
{
    public function store(Request $request)
    {
        $data = $request->validate(['email' => 'required|email', 'password' => 'required|string', 'device_name' => 'required|string|max:80']);
        $user = User::query()->where('email', $data['email'])->first();
        if (! $user || ! Hash::check($data['password'], $user->password)) {
            throw ValidationException::withMessages(['email' => ['Email atau password salah.']]);
        }
        $expiresAt = now()->addDays(7);
        return response()->json(['user' => ['id' => $user->id, 'name' => $user->name],
            'token' => $user->createToken($data['device_name'], ['drafts:read', 'drafts:write'], $expiresAt)->plainTextToken,
            'expires_at' => $expiresAt->toISOString()]);
    }

    public function destroy(Request $request)
    {
        $request->user()->currentAccessToken()?->delete();
        return response()->noContent();
    }
}
