# enhance_cms_zentrydev_themes_full.md

> **ROLE & MODE**
> You are **Claude Code acting as a world-class Senior Full‑Stack Laravel Engineer at a top global IT company**.  
> Operate **non‑interactively** and **autonomously**. Do **not** ask for confirmations. If a step fails, fix and retry until it passes or clearly print the failing step and stop.

> **EXECUTION DIRECTIVE**
> Proceed automatically with all tasks, use existing `gh` authentication or `$GITHUB_TOKEN` if present, clone the monorepo if missing, and **push to GitHub** when finished. All commands run on a Linux host. Use `set -euo pipefail` for shell blocks.

## 0) Context
- Monorepo: `aunji/internal_ai_lab`  
- Project path: `/home/aunji/internal_ai_lab/cms_zentrydev`  
- App: Laravel CMS + Catalog with Filament & Spatie packages already present  
- Goal: Build an **Advanced Custom Theme System** (Wix‑like sections/blocks + live preview + draft/publish) with **6 starter themes**, Filament admin pages (Theme Switcher, Theme Customizer, Page Builder), builder rendering pipeline, sample data, tests, and CI‑ready commit.

---

## 1) Preflight
```bash
set -euo pipefail
# Ensure repo exists locally
if [ ! -d "/home/aunji/internal_ai_lab" ]; then
  if gh repo view "aunji/internal_ai_lab" >/dev/null 2>&1; then
    gh repo clone "aunji/internal_ai_lab" "/home/aunji/internal_ai_lab"
  else
    gh repo create "aunji/internal_ai_lab" --private -y
    gh repo clone "aunji/internal_ai_lab" "/home/aunji/internal_ai_lab"
  fi
fi

cd /home/aunji/internal_ai_lab/cms_zentrydev
php artisan --version
composer --version
```

---

## 2) Database: Themes & Builder Columns
Create migrations for `themes`, `theme_settings`, and builder fields on `posts` (if missing).
```bash
applypatch <<'PATCH'
*** Begin Patch
*** Add File: database/migrations/2025_01_10_000100_create_themes_tables.php
+<?php
+use Illuminate\Database\Migrations\Migration;
+use Illuminate\Database\Schema\Blueprint;
+use Illuminate\Support\Facades\Schema;
+
+return new class extends Migration {
+  public function up(): void {
+    if (!Schema::hasTable('themes')) {
+      Schema::create('themes', function (Blueprint $t) {
+        $t->id();
+        $t->string('key')->unique();
+        $t->string('name');
+        $t->string('version')->default('1.0.0');
+        $t->string('author')->nullable();
+        $t->boolean('is_active')->default(false);
+        $t->text('description')->nullable();
+        $t->string('screenshot_url')->nullable();
+        $t->json('options')->nullable();     // variables + available sections
+        $t->timestamps();
+      });
+    }
+
+    if (!Schema::hasTable('theme_settings')) {
+      Schema::create('theme_settings', function (Blueprint $t) {
+        $t->id();
+        $t->foreignId('theme_id')->constrained('themes')->cascadeOnDelete();
+        $t->string('scope')->default('global'); // 'global' or 'page:<id>'
+        $t->json('values')->nullable();         // CSS vars map
+        $t->timestamps();
+        $t->unique(['theme_id','scope']);
+      });
+    }
+
+    Schema::table('posts', function(Blueprint $t){
+      if (!Schema::hasColumn('posts','layout_json')) $t->json('layout_json')->nullable();
+      if (!Schema::hasColumn('posts','theme_key')) $t->string('theme_key')->nullable();
+      if (!Schema::hasColumn('posts','is_draft')) $t->boolean('is_draft')->default(false);
+    });
+  }
+  public function down(): void {
+    Schema::table('posts', function(Blueprint $t){
+      if (Schema::hasColumn('posts','layout_json')) $t->dropColumn('layout_json');
+      if (Schema::hasColumn('posts','theme_key')) $t->dropColumn('theme_key');
+      if (Schema::hasColumn('posts','is_draft')) $t->dropColumn('is_draft');
+    });
+    if (Schema::hasTable('theme_settings')) Schema::drop('theme_settings');
+    if (Schema::hasTable('themes')) Schema::drop('themes');
+  }
+};
*** End Patch
PATCH
php artisan migrate
```

---

## 3) Models & Service Container
```bash
applypatch <<'PATCH'
*** Begin Patch
*** Add File: app/Models/Theme.php
+<?php
+namespace App\Models;
+use Illuminate\Database\Eloquent\Model;
+class Theme extends Model {
+  protected $fillable = ['key','name','version','author','is_active','description','screenshot_url','options'];
+  protected $casts = ['is_active'=>'bool','options'=>'array'];
+  public function settings(){ return $this->hasMany(ThemeSetting::class); }
+}
*** End Patch
PATCH

applypatch <<'PATCH'
*** Begin Patch
*** Add File: app/Models/ThemeSetting.php
+<?php
+namespace App\Models;
+use Illuminate\Database\Eloquent\Model;
+class ThemeSetting extends Model {
+  protected $fillable = ['theme_id','scope','values'];
+  protected $casts = ['values'=>'array'];
+  public function theme(){ return $this->belongsTo(Theme::class); }
+}
*** End Patch
PATCH

applypatch <<'PATCH'
*** Begin Patch
*** Add File: app/Services/ThemeManager.php
+<?php
+namespace App\Services;
+use App\Models\Theme;
+use Illuminate\Support\Arr;
+
+class ThemeManager {
+  public function active(): ?Theme { return Theme::where('is_active', true)->first(); }
+  public function byKey(string $key): ?Theme { return Theme::where('key',$key)->first(); }
+  public function setActive(string $key): ?Theme {
+    Theme::query()->update(['is_active'=>false]);
+    $t = Theme::firstOrCreate(['key'=>$key], ['name'=>ucfirst($key)]);
+    $t->is_active = true; $t->save(); return $t;
+  }
+  public function list() { return Theme::orderByDesc('is_active')->orderBy('name')->get(); }
+  public function globalCssVars(?Theme $theme=null): array {
+    $t = $theme ?: $this->active(); if (!$t) return [];
+    $values = optional($t->settings()->where('scope','global')->first())->values ?? [];
+    $defaults = Arr::get($t->options,'variables',[]);
+    return array_merge($defaults, $values);
+  }
+  public function availableSections(?Theme $theme=null): array {
+    $t = $theme ?: $this->active(); if (!$t) return [];
+    return Arr::get($t->options,'sections',[]);
+  }
+}
*** End Patch
PATCH

applypatch <<'PATCH'
*** Begin Patch
*** Update File: app/Providers/AppServiceProvider.php
@@
     public function register(): void
     {
+        $this->app->singleton(\App\Services\ThemeManager::class, fn() => new \App\Services\ThemeManager());
     }
*** End Patch
PATCH
```

---

## 4) Theme Files (resources/themes/*)
Create 6 starter themes with a base layout and standard sections.
```bash
set -euo pipefail
for T in nova sleek minimal classic corporate play; do
  mkdir -p "resources/themes/$T/layouts" "resources/themes/$T/sections"
  cat > "resources/themes/$T/layouts/base.blade.php" <<'BLADE'
<!doctype html>
<html lang="th" class="min-h-full">
<head>
  <meta charset="utf-8"/><meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>@yield('title', config('app.name'))</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    :root{
      --color-primary: {{ $themeVars['color.primary'] ?? '#4f46e5' }};
      --color-secondary: {{ $themeVars['color.secondary'] ?? '#06b6d4' }};
      --radius: {{ $themeVars['radius'] ?? '12px' }};
      --container: {{ $themeVars['container'] ?? '72rem' }};
    }
  </style>
</head>
<body class="bg-slate-50 text-slate-900">
  <header class="bg-white/90 backdrop-blur border-b">
    <div class="mx-auto px-4 py-3" style="max-width: var(--container)">
      <div class="flex items-center justify-between">
        <a href="/" class="font-semibold">{{ config('app.name') }}</a>
        <nav class="space-x-4"><a href="/">Home</a><a href="/blog">Blog</a><a href="/catalog">Catalog</a></nav>
      </div>
    </div>
  </header>
  <main class="mx-auto px-4 py-10" style="max-width: var(--container)">
    @yield('content')
  </main>
  <footer class="border-t">
    <div class="mx-auto px-4 py-6 text-sm text-slate-500" style="max-width: var(--container)">
      © {{ date('Y') }} {{ config('app.name') }} · Powered by PHV CMS
    </div>
  </footer>
</body></html>
BLADE
  # Sections
  cat > "resources/themes/$T/sections/hero.blade.php" <<'BLADE'
<section class="py-12 md:py-16">
  <div class="grid md:grid-cols-2 gap-10 items-center">
    <div>
      <p class="text-sm uppercase tracking-wider text-slate-500">{{ $data['eyebrow'] ?? 'New' }}</p>
      <h1 class="text-4xl font-semibold mt-2" style="color: var(--color-primary);">{{ $data['title'] ?? 'Modern Company Website' }}</h1>
      <p class="mt-3 text-slate-600">{{ $data['subtitle'] ?? 'Fast, beautiful, and easy to manage.' }}</p>
      @if(!empty($data['cta']))
      <div class="mt-5 flex gap-3">
        @foreach($data['cta'] as $c)
          <a href="{{ $c['href'] ?? '#' }}" class="px-5 py-3 rounded" style="background: var(--color-primary); color:white">{{ $c['label'] ?? 'Learn more' }}</a>
        @endforeach
      </div>
      @endif
    </div>
    <div>
      <img class="rounded-xl w-full object-cover" style="border-radius: var(--radius);" src="{{ $data['image'] ?? 'https://picsum.photos/1200/700' }}" alt="">
    </div>
  </div>
</section>
BLADE
  cat > "resources/themes/$T/sections/features.blade.php" <<'BLADE'
<section class="py-10">
  <h2 class="text-2xl font-semibold mb-6">{{ $data['heading'] ?? 'ครบทุกอย่างที่ต้องการ' }}</h2>
  <div class="grid md:grid-cols-3 gap-6">
    @foreach(($data['items'] ?? []) as $i)
      <div class="bg-white rounded-xl p-5 border">
        <div class="font-medium">{{ $i['title'] ?? 'Feature' }}</div>
        <div class="text-sm text-slate-600 mt-1">{{ $i['desc'] ?? '' }}</div>
      </div>
    @endforeach
  </div>
</section>
BLADE
  cat > "resources/themes/$T/sections/cta.blade.php" <<'BLADE'
<section class="py-12 text-center">
  <h3 class="text-2xl font-semibold">{{ $data['title'] ?? 'พร้อมเริ่มต้น?' }}</h3>
  <p class="text-slate-600 mt-2">{{ $data['desc'] ?? '' }}</p>
  <a href="{{ $data['href'] ?? '#' }}" class="inline-flex mt-5 px-6 py-3 rounded-lg text-white" style="background: var(--color-secondary);"> {{ $data['button'] ?? 'ติดต่อเรา' }} </a>
</section>
BLADE
  cat > "resources/themes/$T/sections/testimonials.blade.php" <<'BLADE'
<section class="py-12">
  <h3 class="text-xl font-semibold mb-6">{{ $data['heading'] ?? 'เสียงจากลูกค้า' }}</h3>
  <div class="grid md:grid-cols-3 gap-6">
    @foreach(($data['items'] ?? []) as $t)
      <div class="bg-white border rounded-xl p-5">
        <div class="text-amber-400">{{ str_repeat('★', $t['stars'] ?? 5) }}</div>
        <p class="text-sm mt-2">{{ $t['text'] ?? '' }}</p>
        <div class="text-xs text-slate-500 mt-3">— {{ $t['author'] ?? 'ลูกค้า' }}</div>
      </div>
    @endforeach
  </div>
</section>
BLADE
  cat > "resources/themes/$T/sections/gallery.blade.php" <<'BLADE'
<section class="py-10">
  <h3 class="text-xl font-semibold mb-4">{{ $data['heading'] ?? 'แกลเลอรี' }}</h3>
  <div class="grid md:grid-cols-3 gap-3">
    @foreach(($data['images'] ?? []) as $img)
      <img class="w-full aspect-video object-cover rounded" src="{{ $img }}" alt="">
    @endforeach
  </div>
</section>
BLADE
  cat > "resources/themes/$T/sections/logowall.blade.php" <<'BLADE'
<section class="py-8">
  <div class="text-xs text-slate-500 mb-3">{{ $data['heading'] ?? 'Trusted by' }}</div>
  <div class="flex flex-wrap gap-6 items-center opacity-80">
    @foreach(($data['logos'] ?? []) as $lg)
      <img src="{{ $lg }}" class="h-8 object-contain" alt="">
    @endforeach
  </div>
</section>
BLADE
  cat > "resources/themes/$T/config.php" <<'PHP'
<?php
return [
  'variables' => [
    'color.primary' => '#4f46e5',
    'color.secondary' => '#06b6d4',
    'radius' => '14px',
    'container' => '72rem',
  ],
  'sections' => ['hero','features','cta','testimonials','gallery','logowall'],
];
PHP
done
```

---

## 5) Middleware to inject theme vars
```bash
applypatch <<'PATCH'
*** Begin Patch
*** Add File: app/Http/Middleware/InjectThemeVars.php
+<?php
+namespace App\Http\Middleware;
+use Closure;
+use App\Services\ThemeManager;
+
+class InjectThemeVars {
+    public function handle($request, Closure $next){
+        $tm = app(ThemeManager::class);
+        $activeKey = $request->query('preview_theme') ?: optional($tm->active())->key;
+        $theme = $activeKey ? $tm->byKey($activeKey) : $tm->active();
+        view()->composer('*', function ($view) use ($tm, $theme) {
+            $view->with('activeTheme', $theme?->key ?? 'nova');
+            $view->with('themeVars', $tm->globalCssVars($theme));
+        });
+        return $next($request);
+    }
+}
*** End Patch
PATCH

applypatch <<'PATCH'
*** Begin Patch
*** Update File: app/Http/Kernel.php
@@
         'web' => [
             \App\Http\Middleware\EncryptCookies::class,
             \Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse::class,
             \Illuminate\Session\Middleware\StartSession::class,
+            \App\Http\Middleware\InjectThemeVars::class,
             \Illuminate\View\Middleware\ShareErrorsFromSession::class,
             \App\Http\Middleware\VerifyCsrfToken::class,
             \Illuminate\Routing\Middleware\SubstituteBindings::class,
         ],
*** End Patch
PATCH
```

---

## 6) Theme View Resolver & Builder Rendering
```bash
applypatch <<'PATCH'
*** Begin Patch
*** Add File: app/Providers/ThemeViewServiceProvider.php
+<?php
+namespace App\Providers;
+use Illuminate\Support\ServiceProvider;
+class ThemeViewServiceProvider extends ServiceProvider {
+  public function register(): void {
+    foreach (glob(resource_path('themes/*')) as $p) {
+      $key = basename($p);
+      $this->loadViewsFrom(resource_path("themes/$key"), "themes::$key");
+    }
+  }
+  public function boot(): void {}
+}
*** End Patch
PATCH

applypatch <<'PATCH'
*** Begin Patch
*** Update File: config/app.php
@@
         App\Providers\AppServiceProvider::class,
+        App\Providers\ThemeViewServiceProvider::class,
*** End Patch
PATCH

applypatch <<'PATCH'
*** Begin Patch
*** Add File: app/Http/Controllers/Frontend/BuilderController.php
+<?php
+namespace App\Http\Controllers\Frontend;
+use App\Http\Controllers\Controller;
+use App\Models\Post;
+use App\Services\ThemeManager;
+class BuilderController extends Controller {
+  public function show($slug){
+    $page = Post::where('type','page')->where('slug',$slug)->firstOrFail();
+    $tm = app(ThemeManager::class);
+    $themeKey = request('preview_theme') ?: ($page->theme_key ?: optional($tm->active())->key ?? 'nova');
+    $theme = $tm->byKey($themeKey) ?: $tm->active();
+    $layout = $page->layout_json ?: [];
+    if (is_string($layout)) $layout = json_decode($layout, true) ?: [];
+    return view('theme.render', compact('page','layout','themeKey','theme'));
+  }
+}
*** End Patch
PATCH

applypatch <<'PATCH'
*** Begin Patch
*** Add File: resources/views/theme/base.blade.php
+@includeIf("themes::$activeTheme.layouts.base")
*** End Patch
PATCH

applypatch <<'PATCH'
*** Begin Patch
*** Add File: resources/views/theme/render.blade.php
+@php $layout = $layout ?? []; @endphp
+@extends("theme.base")
+@section('title', $page->seo_title ?? $page->title)
+@section('content')
+  @foreach($layout as $block)
+    @php
+      $type = $block['type'] ?? null;
+      $data = $block['data'] ?? [];
+      $file = resource_path("themes/$activeTheme/sections/$type.blade.php");
+    @endphp
+    @if($type && file_exists($file))
+      @include("themes::$activeTheme.sections.$type", ['data'=>$data])
+    @else
+      <div class="p-4 border rounded bg-white my-2">Unknown block: {{ $type }}</div>
+    @endif
+  @endforeach
+@endsection
*** End Patch
PATCH

applypatch <<'PATCH'
*** Begin Patch
*** Update File: routes/web.php
@@
 Route::get('/page/{slug}', [PageController::class, 'show'])->name('page.show');
+Route::get('/builder/{slug}', [\App\Http\Controllers\Frontend\BuilderController::class, 'show'])->name('builder.show');
*** End Patch
PATCH
```

---

## 7) Filament Admin Pages (Themes, Customizer, Page Builder)
```bash
applypatch <<'PATCH'
*** Begin Patch
*** Add File: app/Filament/Pages/ThemeSwitcher.php
+<?php
+namespace App\Filament\Pages;
+use Filament\Pages\Page;
+use Filament\Forms;
+use App\Services\ThemeManager;
+use Filament\Notifications\Notification;
+class ThemeSwitcher extends Page {
+  protected static ?string $navigationIcon = 'heroicon-o-swatch';
+  protected static ?string $navigationLabel = 'Themes';
+  protected static ?string $navigationGroup = 'Appearance';
+  protected static string $view = 'filament.pages.theme-switcher';
+  public $theme_key;
+  protected function getFormSchema(): array {
+    $tm = app(ThemeManager::class);
+    return [ Forms\Components\Select::make('theme_key')->label('Active Theme')->options($tm->list()->pluck('name','key'))->required(), ];
+  }
+  public function mount(): void { $this->form->fill(['theme_key'=>optional(app(ThemeManager::class)->active())->key]); }
+  public function submit(): void {
+    app(ThemeManager::class)->setActive($this->form->getState()['theme_key']);
+    Notification::make()->title('Active theme updated')->success()->send();
+  }
+}
*** End Patch
PATCH

applypatch <<'PATCH'
*** Begin Patch
*** Add File: resources/views/filament/pages/theme-switcher.blade.php
+<x-filament::page>
+  <form wire:submit.prevent="submit">
+    {{ $this->form }}
+    <x-filament::button type="submit" class="mt-4">Save</x-filament::button>
+  </form>
+</x-filament::page>
*** End Patch
PATCH

applypatch <<'PATCH'
*** Begin Patch
*** Add File: app/Filament/Pages/ThemeCustomizer.php
+<?php
+namespace App\Filament\Pages;
+use Filament\Pages\Page;
+use Filament\Forms;
+use App\Services\ThemeManager;
+use Filament\Notifications\Notification;
+class ThemeCustomizer extends Page {
+  protected static ?string $navigationIcon = 'heroicon-o-cog-8-tooth';
+  protected static ?string $navigationLabel = 'Theme Customizer';
+  protected static ?string $navigationGroup = 'Appearance';
+  protected static string $view = 'filament.pages.theme-customizer';
+  public $data = [];
+  protected function getFormSchema(): array {
+    $vars = app(ThemeManager::class)->globalCssVars();
+    $schema = [];
+    foreach ($vars as $k=>$v) { $schema[] = Forms\Components\TextInput::make(\"vars.$k\")->label($k)->default($v); }
+    if (empty($schema)) { $schema[] = Forms\Components\Placeholder::make('hint')->content('No variables defined in active theme.'); }
+    return $schema;
+  }
+  public function mount(): void { $this->form->fill(['vars'=>app(ThemeManager::class)->globalCssVars()]); }
+  public function submit(): void {
+    $tm = app(ThemeManager::class); $t = $tm->active(); $payload = $this->form->getState()['vars'] ?? [];
+    $setting = $t->settings()->firstOrCreate(['scope'=>'global']); $setting->values = $payload; $setting->save();
+    Notification::make()->title('Theme variables saved')->success()->send();
+  }
+}
*** End Patch
PATCH

applypatch <<'PATCH'
*** Begin Patch
*** Add File: resources/views/filament/pages/theme-customizer.blade.php
+<x-filament::page>
+  <form wire:submit.prevent="submit">
+    {{ $this->form }}
+    <x-filament::button type="submit" class="mt-4">Save</x-filament::button>
+  </form>
+</x-filament::page>
*** End Patch
PATCH

applypatch <<'PATCH'
*** Begin Patch
*** Add File: app/Filament/Pages/PageBuilder.php
+<?php
+namespace App\Filament\Pages;
+use Filament\Pages\Page;
+use Filament\Forms;
+use App\Models\Post;
+use App\Services\ThemeManager;
+use Filament\Notifications\Notification;
+class PageBuilder extends Page {
+  protected static ?string $navigationIcon = 'heroicon-o-rectangle-group';
+  protected static ?string $navigationLabel = 'Page Builder';
+  protected static ?string $navigationGroup = 'Appearance';
+  protected static string $view = 'filament.pages.page-builder';
+  public $page_id; public $theme_key; public $blocks = [];
+  protected function getFormSchema(): array {
+    $tm = app(ThemeManager::class); $sections = array_combine($tm->availableSections(), $tm->availableSections());
+    return [
+      Forms\Components\Select::make('page_id')->label('Page')->options(Post::where('type','page')->pluck('title','id'))->reactive()->required(),
+      Forms\Components\Select::make('theme_key')->label('Theme (override)')->options($tm->list()->pluck('name','key')),
+      Forms\Components\Repeater::make('blocks')->label('Sections')->schema([
+        Forms\Components\Select::make('type')->options($sections)->required()->reactive(),
+        Forms\Components\KeyValue::make('data')->label('Data (key:value)')->keyLabel('field')->valueLabel('value'),
+      ])->orderable()->default([]),
+    ];
+  }
+  public function updated($prop): void {
+    if ($prop==='page_id' && $this->page_id) {
+      $p = Post::find($this->page_id); $this->theme_key = $p->theme_key; $this->blocks = $p->layout_json ?: [];
+    }
+  }
+  public function submit(): void {
+    $p = Post::findOrFail($this->page_id); $p->theme_key = $this->theme_key; $p->layout_json = $this->blocks; $p->save();
+    Notification::make()->title('Page layout saved')->success()->send();
+  }
+}
*** End Patch
PATCH

applypatch <<'PATCH'
*** Begin Patch
*** Add File: resources/views/filament/pages/page-builder.blade.php
+<x-filament::page>
+  <form wire:submit.prevent="submit">
+    {{ $this->form }}
+    <div class="mt-4 flex gap-3">
+      <x-filament::button type="submit">Save</x-filament::button>
+      @if($page_id)
+        <a target="_blank" href="{{ route('builder.show', \App\Models\Post::find($page_id)?->slug) }}?preview_theme={{ $theme_key }}" class="inline-flex items-center px-4 py-2 rounded bg-gray-100">Preview</a>
+      @endif
+    </div>
+  </form>
+</x-filament::page>
*** End Patch
PATCH
```

---

## 8) Seed 6 Themes & Activate Default
```bash
applypatch <<'PATCH'
*** Begin Patch
*** Add File: database/seeders/ThemeSeeder.php
+<?php
+namespace Database\Seeders;
+use Illuminate\Database\Seeder;
+use App\Models\Theme;
+class ThemeSeeder extends Seeder {
+  public function run(): void {
+    $list = [
+      ['key'=>'nova','name'=>'Nova'],
+      ['key'=>'sleek','name'=>'Sleek'],
+      ['key'=>'minimal','name'=>'Minimal'],
+      ['key'=>'classic','name'=>'Classic'],
+      ['key'=>'corporate','name'=>'Corporate'],
+      ['key'=>'play','name'=>'Playful'],
+    ];
+    foreach($list as $t){
+      $opts = include resource_path("themes/{$t['key']}/config.php");
+      Theme::updateOrCreate(['key'=>$t['key']], [
+        'name'=>$t['name'], 'version'=>'1.0.0', 'author'=>'ZentryDev',
+        'description'=>'Starter theme', 'options'=>$opts, 'is_active'=>false,
+      ]);
+    }
+    Theme::query()->update(['is_active'=>false]);
+    if ($a = Theme::where('key','nova')->first()) { $a->is_active = true; $a->save(); }
+  }
+}
*** End Patch
PATCH

php artisan db:seed --class=Database\\Seeders\\ThemeSeeder
```

---

## 9) Demo Builder Page Data
```bash
php -r '
use App\Models\Post;
$p = Post::firstOrCreate(["slug"=>"home"],["type"=>"page","title"=>"Home","status"=>"published"]);
$p->theme_key = "nova";
$p->layout_json = [
  ["type"=>"hero","data"=>["eyebrow"=>"PHV CMS","title"=>"สวย เร็ว ปรับแต่งง่าย","subtitle"=>"ปรับธีมและส่วนต่างๆ ได้เหมือนเว็บไซต์ตัวต่อ","cta"=>[["label"=>"ดูแคตตาล็อก","href"=>"/catalog"],["label"=>"อ่านบทความ","href"=>"/blog"]],"image"=>"https://picsum.photos/1200/700?random=20"]],
  ["type"=>"features","data"=>["heading"=>"ครบในที่เดียว","items"=>[["title"=>"Page & Blog","desc"=>"เพจและบทความพร้อม SEO"],["title"=>"Catalog","desc"=>"สินค้า สเปค แกลเลอรี"],["title"=>"Menus","desc"=>"ลากเรียงซ้อนชั้นได้"]]]],
  ["type"=>"testimonials","data"=>["heading"=>"ลูกค้าชอบ","items"=>[["stars"=>5,"text"=>"ทำเว็บเร็วมาก","author"=>"A."],["stars"=>5,"text"=>"ปรับธีมง่ายดี","author"=>"B."],["stars"=>4,"text"=>"เนียนตา","author"=>"C."]]]],
  ["type"=>"cta","data"=>["title"=>"พร้อมเริ่ม?","desc"=>"ลองหน้าเดโมได้เลย","button"=>"ไปต่อ","href"=>"/catalog"]],
];
$p->save();
echo "Seeded Home builder\n";
'
```

---

## 10) Tests
```bash
applypatch <<'PATCH'
*** Begin Patch
*** Add File: tests/Feature/ThemeBuilderTest.php
+<?php
+use Illuminate\Foundation\Testing\RefreshDatabase;
+use App\Models\Post;
+uses(RefreshDatabase::class);
+it('renders builder page', function(){
+    $p = Post::factory()->create(['type'=>'page','slug'=>'landing','title'=>'Landing','layout_json'=>json_encode([]),'status'=>'published']);
+    $this->get('/builder/landing')->assertStatus(200);
+});
*** End Patch
PATCH

php artisan test --without-tty
```

---

## 11) Optimize, Commit & Push
```bash
set -euo pipefail
php artisan optimize
php artisan test --without-tty

cd /home/aunji/internal_ai_lab
git add cms_zentrydev
git commit -m "feat(cms_zentrydev): custom theme system (registry, variables, sections, builder, preview) + 6 starter themes + Filament pages"
git pull --rebase --autostash || true
git push -u origin main || true
```

---

## 12) Output (print)
Print (stdout):
- Active theme key
- List of registered themes
- Builder route for demo: `/builder/home`
- Admin pages:
  - `/admin` → **Themes** (ThemeSwitcher)
  - `/admin` → **Theme Customizer**
  - `/admin` → **Page Builder**
- Tip: preview another theme via `?preview_theme=sleek`

> End of prompt.


คุณทำถึงส่วนนี้ก่อนที่จะ ถึง limit


● Bash(php artisan make:model Theme)
  ⎿     INFO  Model [app/Models/Theme.php] created successfully.

● Bash(php artisan make:model ThemeSetting)
  ⎿     INFO  Model [app/Models/ThemeSetting.php] created successfully.

● Read(app/Models/Theme.php)
  ⎿  Read 12 lines

● Update(app/Models/Theme.php)
  ⎿  Updated app/Models/Theme.php with 38 additions                              
        8    class Theme extends Model
        9    {
       10        use HasFactory;
       11 +  
       12 +      protected $fillable = [
       13 +          'key',
       14 +          'name',
       15 +          'version',
       16 +          'author',
       17 +          'is_active',
       18 +          'options',
       19 +      ];
       20 +  
       21 +      protected $casts = [
       22 +          'options' => 'array',
       23 +          'is_active' => 'boolean',
       24 +      ];
       25 +  
       26 +      /**
       27 +       * Get theme settings
       28 +       */
       29 +      public function settings()
       30 +      {
       31 +          return $this->hasMany(ThemeSetting::class);
       32 +      }
       33 +  
       34 +      /**
       35 +       * Get global settings for this theme
       36 +       */
       37 +      public function globalSettings()
       38 +      {
       39 +          return $this->settings()->where('scope', 'global')->first();
       40 +      }
       41 +  
       42 +      /**
       43 +       * Scope to get active theme
       44 +       */
       45 +      public function scopeActive($query)
       46 +      {
       47 +          return $query->where('is_active', true);
       48 +      }
       49    }

● Read(app/Models/ThemeSetting.php)
  ⎿  Read 12 lines

● Update(app/Models/ThemeSetting.php)
  ⎿  Updated app/Models/ThemeSetting.php with 18 additions 
        8    class ThemeSetting extends Model
        9    {
       10        use HasFactory;
       11 +  
       12 +      protected $fillable = [
       13 +          'theme_id',
       14 +          'scope',
       15 +          'values',
       16 +      ];
       17 +  
       18 +      protected $casts = [
       19 +          'values' => 'array',
       20 +      ];
       21 +  
       22 +      /**
       23 +       * Get the theme that owns this setting
       24 +       */
       25 +      public function theme()
       26 +      {
       27 +          return $this->belongsTo(Theme::class);
       28 +      }
       29    }

● Write(app/Services/ThemeManager.php)
  ⎿  Wrote 114 lines to app/Services/ThemeManager.php
     <?php
     namespace App\Services;
     use App\Models\Theme;
     use Illuminate\Support\Facades\Cache;
     class ThemeManager
     {
         /**
     … +104 lines (ctrl+o to expand)

● Read(app/Providers/AppServiceProvider.php)
  ⎿  Read 25 lines

● Update(app/Providers/AppServiceProvider.php)
  ⎿  Updated app/Providers/AppServiceProvider.php with 3 additions and 1 removal               
       11         */
       12        public function register(): void
       13        {
       14 -          //
       14 +          $this->app->singleton(\App\Services\ThemeManager::class, function ($app) {
       15 +              return new \App\Services\ThemeManager();
       16 +          });
       17        }
       18    
       19        /**

● Bash(mkdir -p
      /home/aunji/internal_ai_lab/cms_zentrydev/resources/themes/{nova,sleek,minimal,classic,corporate,play}/{layouts,sections})
  ⎿  (No content)

● Now I'll create base layout and sections for each theme. Let me start with the Nova theme:

● Write(resources/themes/nova/layouts/base.blade.php)
  ⎿  Wrote 44 lines to resources/themes/nova/layouts/base.blade.php            
     <!DOCTYPE html>
     <html lang="en">
     <head>
         <meta charset="UTF-8">
         <meta name="viewport" content="width=device-width, initial-scale=1.0">
         <title>@yield('title', 'Nova Theme')</title>
         <script src="https://cdn.tailwindcss.com"></script>
         <style>
             {!! app(\App\Services\ThemeManager::class)->generateCssVars() !!}
             body {
     … +34 lines (ctrl+o to expand)

● Due to the large number of files to create, let me use the Task tool to speed up the process:

● Task(Create theme section files)
  ⎿  Done (6 tool uses · 0 tokens · 1m 15s)                                                                                       

● Task(Create Sleek theme files)
  ⎿  Done (1 tool use · 0 tokens · 5.1s)                                                                                          

● Task(Create Minimal theme files)
  ⎿  Done (2 tool uses · 0 tokens · 9.5s)                                                                                         

● Task(Create Classic, Corporate, Play themes)
  ⎿  Done (1 tool use · 0 tokens · 19.6s)                                                                                         
  ⎿  Session limit reached ∙ resets 4pm
     /upgrade to increase your usage limit.
