<?php

namespace App\Filament\Resources;

use App\Filament\Resources\OfflineDraftResource\Pages\ListOfflineDrafts;
use App\Models\OfflineDraft;
use Filament\Resources\Resource;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class OfflineDraftResource extends Resource
{
    protected static ?string $model = OfflineDraft::class;

    public static function canViewAny(): bool { return (bool) auth()->user()?->is_admin; }
    public static function canCreate(): bool { return false; }
    public static function canEdit($record): bool { return false; }
    public static function canDelete($record): bool { return false; }

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()->where('user_id', auth()->id());
    }

    public static function table(Table $table): Table
    {
        return $table->columns([
            TextColumn::make('uuid')->label('ID')->copyable(),
            TextColumn::make('title')->label('Judul')->searchable(),
            TextColumn::make('notes')->label('Catatan')->limit(60),
            TextColumn::make('created_at')->label('Diterima server')->dateTime(),
        ])->defaultSort('id', 'desc');
    }

    public static function getPages(): array { return ['index' => ListOfflineDrafts::route('/')]; }
}
