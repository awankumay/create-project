<?php

use App\Models\User;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Validator;

Artisan::command('starter:user {email} {--name=Administrator} {--admin}', function () {
    $email = (string) $this->argument('email');
    $password = $this->secret('Password baru (minimal 12 karakter)');
    $data = ['email' => $email, 'password' => $password, 'name' => $this->option('name')];
    $validator = Validator::make($data, ['email' => 'required|email|unique:users,email', 'password' => 'required|string|min:12', 'name' => 'required|string|max:100']);
    if ($validator->fails()) { $this->error($validator->errors()->first()); return 1; }
    $user = new User($data);
    $user->is_admin = (bool) $this->option('admin');
    $user->save();
    $this->info('User dibuat. Tidak ada password default.');
    return 0;
})->purpose('Create a starter account without a hard-coded password');
