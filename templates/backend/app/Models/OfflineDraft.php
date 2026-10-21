<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class OfflineDraft extends Model
{
    protected $fillable = ['uuid', 'user_id', 'device_id', 'title', 'notes'];
}
