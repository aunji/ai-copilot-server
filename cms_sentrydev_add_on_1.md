act you is senior laravel dev in world company IT Run non-interactively. Proceed automatically with all tasks, do not ask again, use existing gh authentication, clone if needed, and push when done.

0) ข้อกำหนด

โค้ดอยู่: /home/aunji/internal_ai_lab/cms_zentrydev (มี Laravel + Tailwind CDN แล้ว)

Repo monorepo: aunji/internal_ai_lab (โฟลเดอร์ cms_zentrydev/)

ใช้ SQLite dev ต่อไป

หลังปรับเสร็จ: run tests, commit, push ไป main

1) Landing Page ใหม่ (สวยมาก + responsive + dark mode)

แก้ไฟล์ resources/views/home.blade.php ทั้งไฟล์ให้เป็น Landing ใหม่:

@extends('layouts.app')
@section('title', config('app.name').' — Modern CMS & Catalog')
@section('content')
{{-- Dark mode toggle (localStorage) --}}
<script>
  (()=>{const k='phv-theme'; const d=document.documentElement; const t=localStorage.getItem(k);
    if(!t && window.matchMedia('(prefers-color-scheme: dark)').matches) d.classList.add('dark');
    else if(t==='dark') d.classList.add('dark');})();
  function toggleTheme(){ const k='phv-theme'; const d=document.documentElement;
    d.classList.toggle('dark'); localStorage.setItem(k, d.classList.contains('dark')?'dark':'light'); }
</script>

<div class="relative overflow-hidden">
  <div class="absolute inset-0 bg-gradient-to-b from-slate-50 to-white dark:from-slate-900 dark:to-slate-950 pointer-events-none"></div>

  {{-- NAV AUX --}}
  <div class="flex justify-end mb-2">
    <button onclick="toggleTheme()" class="text-sm px-3 py-1.5 border rounded bg-white/70 backdrop-blur hover:bg-white dark:text-slate-100 dark:bg-slate-800 dark:border-slate-700">
      Toggle theme
    </button>
  </div>

  {{-- HERO --}}
  <section class="relative z-10 px-4 py-12 md:py-20">
    <div class="max-w-6xl mx-auto grid md:grid-cols-12 gap-10 items-center">
      <div class="md:col-span-7">
        <span class="inline-flex items-center px-3 py-1 rounded-full border text-xs uppercase tracking-wider bg-white/70 dark:bg-slate-800/60 dark:border-slate-700">
          New • PHV CMS & Catalog
        </span>
        <h1 class="mt-4 text-4xl md:text-5xl font-semibold leading-tight text-slate-900 dark:text-slate-100">
          สร้างเว็บไซต์บริษัท & แคตตาล็อก <span class="text-transparent bg-clip-text bg-gradient-to-r from-indigo-500 to-violet-500">สวย เร็ว ปรับแต่งง่าย</span>
        </h1>
        <p class="mt-4 text-slate-600 dark:text-slate-300 max-w-2xl">
          หน้าบ้านเร็วลื่นด้วย Tailwind, หลังบ้านจัดการด้วย Filament.
          รองรับเพจ/บทความ/สินค้า พร้อม SEO + JSON-LD ครบ จัดการเมนูได้ ลากเรียงได้.
        </p>
        <div class="mt-6 flex flex-wrap gap-3">
          <a href="{{ route('catalog.index') }}" class="px-5 py-3 rounded-lg bg-slate-900 text-white hover:bg-slate-700">ดูแคตตาล็อก</a>
          <a href="{{ route('blog.index') }}" class="px-5 py-3 rounded-lg border hover:bg-white dark:hover:bg-slate-800">อ่านบทความ</a>
          <a href="/admin" class="px-5 py-3 rounded-lg border border-indigo-300 bg-indigo-50 text-indigo-700 hover:bg-indigo-100 dark:border-indigo-700/40 dark:bg-indigo-900/30 dark:text-indigo-200">เข้าสู่แอดมิน</a>
        </div>
        {{-- Logo wall --}}
        <div class="mt-10 opacity-80">
          <div class="text-xs text-slate-500 mb-2">Powered by</div>
          <div class="flex flex-wrap gap-6 items-center">
            <div class="text-slate-500">Laravel</div>
            <div class="text-slate-500">Filament</div>
            <div class="text-slate-500">Spatie</div>
            <div class="text-slate-500">Tailwind</div>
          </div>
        </div>
      </div>
      <div class="md:col-span-5">
        <div class="bg-white dark:bg-slate-900 border dark:border-slate-700 rounded-2xl shadow-lg p-4">
          <img src="https://picsum.photos/1200/700?grayscale" class="rounded-lg w-full object-cover" alt="">
        </div>
      </div>
    </div>
  </section>

  {{-- FEATURES --}}
  <section class="relative z-10 px-4 py-12">
    <div class="max-w-6xl mx-auto">
      <h2 class="text-2xl font-semibold mb-6">ครบในที่เดียว</h2>
      <div class="grid md:grid-cols-3 gap-6">
        @foreach([
          ['หัวข้อ'=>'Pages & Blog','รายละเอียด'=>'จัดการเพจ/โพสต์ พร้อมหมวด/แท็ก, ดราฟท์/เผยแพร่, SEO'],
          ['หัวข้อ'=>'Product Catalog','รายละเอียด'=>'สินค้า, หมวด, ไฮไลท์, สเปค, แกลเลอรี, JSON-LD Product'],
          ['หัวข้อ'=>'Menus Builder','รายละเอียด'=>'สร้างเมนูหัว/ท้าย, ซ้อนชั้น, ลากเรียง, cache เร็ว'],
          ['หัวข้อ'=>'Search','รายละเอียด'=>'ค้นหาหน้าบ้านแบบเร็ว (simple like)'],
          ['หัวข้อ'=>'Media Library','รายละเอียด'=>'อัปโหลดรูป/ไฟล์ด้วย Spatie Medialibrary'],
          ['หัวข้อ'=>'Permissions','รายละเอียด'=>'บทบาท Admin/Editor/Author พร้อม activity log'],
        ] as $f)
        <div class="bg-white dark:bg-slate-900 border dark:border-slate-700 rounded-xl p-5">
          <div class="font-medium">{{ $f['หัวข้อ'] }}</div>
          <div class="text-slate-600 dark:text-slate-300 text-sm mt-1">{{ $f['รายละเอียด'] }}</div>
        </div>
        @endforeach
      </div>
    </div>
  </section>

  {{-- HIGHLIGHTS: recent posts & featured products (ถ้ามี) --}}
  <section class="relative z-10 px-4 py-12">
    <div class="max-w-6xl mx-auto grid md:grid-cols-2 gap-8">
      {{-- Recent posts --}}
      <div>
        <h3 class="text-xl font-semibold mb-4">บทความล่าสุด</h3>
        @php $recent = \App\Models\Post::where('type','post')->where('status','published')->latest('published_at')->take(3)->get(); @endphp
        <div class="space-y-3">
          @forelse($recent as $post)
            <a href="{{ route('blog.show',$post->slug) }}" class="block bg-white dark:bg-slate-900 border dark:border-slate-700 rounded-lg p-4 hover:shadow">
              <div class="font-medium">{{ $post->title }}</div>
              <div class="text-sm text-slate-600 dark:text-slate-400 line-clamp-2">{{ $post->excerpt }}</div>
            </a>
          @empty
            <div class="text-slate-500 text-sm">ยังไม่มีบทความ</div>
          @endforelse
        </div>
      </div>
      {{-- Featured products --}}
      <div>
        <h3 class="text-xl font-semibold mb-4">สินค้าแนะนำ</h3>
        @php $featured = \App\Models\Product::where('status','published')->latest()->take(3)->get(); @endphp
        <div class="grid md:grid-cols-3 gap-4">
          @forelse($featured as $p)
            <a href="{{ route('catalog.product',$p->slug) }}" class="block bg-white dark:bg-slate-900 border dark:border-slate-700 rounded-lg overflow-hidden hover:shadow">
              <img class="w-full aspect-video object-cover" src="{{ $p->getFirstMediaUrl('images') ?: 'https://picsum.photos/800/450' }}" alt="">
              <div class="p-3">
                <div class="text-sm font-medium line-clamp-2">{{ $p->title }}</div>
                @if(!is_null($p->price) && config('cms.catalog.show_price'))
                  <div class="text-xs text-slate-600 dark:text-slate-400">{{ number_format($p->price/100,2) }} ฿</div>
                @endif
              </div>
            </a>
          @empty
            <div class="text-slate-500 text-sm">ยังไม่มีสินค้า</div>
          @endforelse
        </div>
      </div>
    </div>
  </section>

  {{-- TESTIMONIALS + CTA --}}
  <section class="relative z-10 px-4 py-16">
    <div class="max-w-4xl mx-auto text-center">
      <h3 class="text-2xl font-semibold">ลูกค้าพูดถึงเรา</h3>
      <div class="mt-6 grid md:grid-cols-3 gap-6">
        @foreach([5,5,4] as $stars)
          <div class="bg-white dark:bg-slate-900 border dark:border-slate-700 rounded-xl p-5">
            <div class="text-amber-400">{{ str_repeat('★',$stars) }}{{ str_repeat('☆',5-$stars) }}</div>
            <p class="text-sm text-slate-600 dark:text-slate-300 mt-2">“จัดการคอนเทนต์เร็วขึ้นเยอะ ดีไซน์สวย ใช้งานง่าย”</p>
            <div class="text-xs text-slate-500 mt-3">— ผู้ใช้จริง</div>
          </div>
        @endforeach
      </div>
      <div class="mt-10">
        <a href="{{ route('catalog.index') }}" class="inline-flex px-6 py-3 rounded-lg bg-indigo-600 text-white hover:bg-indigo-500">เริ่มสำรวจสินค้า</a>
      </div>
    </div>
  </section>
</div>
@endsection


หมายเหตุ: ใช้ Tailwind CDN อยู่แล้วใน layouts/app.blade.php — รองรับ dark mode ด้วย html.dark

2) เพิ่ม/อัปเกรด Filament
2.1 Filament Settings Page (จัดการ SiteSettings)

สร้างหน้า Settings ในแอดมิน: app/Filament/Pages/SiteSettingsPage.php

<?php
namespace App\Filament\Pages;

use Filament\Forms;
use Filament\Pages\Page;
use App\Settings\SiteSettings;
use Filament\Notifications\Notification;

class SiteSettingsPage extends Page
{
    protected static ?string $navigationIcon = 'heroicon-o-cog-6-tooth';
    protected static string $view = 'filament.pages.site-settings-page';
    protected static ?string $navigationLabel = 'Site Settings';
    protected static ?string $navigationGroup = 'Configuration';
    protected static ?int $navigationSort = 90;

    public $data = [];

    public function mount(): void
    {
        $s = app(SiteSettings::class);
        $this->form->fill([
            'site_name' => $s->site_name ?? config('app.name'),
            'facebook' => $s->facebook,
            'x' => $s->x,
            'instagram' => $s->instagram,
            'google_analytics_id' => $s->google_analytics_id,
            'contact_email' => $s->contact_email,
            'contact_phone' => $s->contact_phone,
            'address' => $s->address,
        ]);
    }

    protected function getFormSchema(): array
    {
        return [
            Forms\Components\TextInput::make('site_name')->label('Site Name')->required(),
            Forms\Components\TextInput::make('contact_email')->email(),
            Forms\Components\TextInput::make('contact_phone'),
            Forms\Components\Textarea::make('address')->rows(2),
            Forms\Components\Fieldset::make('Social')->schema([
                Forms\Components\TextInput::make('facebook'),
                Forms\Components\TextInput::make('x'),
                Forms\Components\TextInput::make('instagram'),
                Forms\Components\TextInput::make('google_analytics_id')->helperText('e.g. G-XXXX'),
            ]),
        ];
    }

    protected function getFormModel(): SiteSettings
    {
        return app(SiteSettings::class);
    }

    public function submit(): void
    {
        /** @var SiteSettings $s */
        $s = app(SiteSettings::class);
        $s->site_name = $this->form->getState()['site_name'];
        $s->facebook = $this->form->getState()['facebook'] ?? null;
        $s->x = $this->form->getState()['x'] ?? null;
        $s->instagram = $this->form->getState()['instagram'] ?? null;
        $s->google_analytics_id = $this->form->getState()['google_analytics_id'] ?? null;
        $s->contact_email = $this->form->getState()['contact_email'] ?? null;
        $s->contact_phone = $this->form->getState()['contact_phone'] ?? null;
        $s->address = $this->form->getState()['address'] ?? null;
        $s->save();

        Notification::make()->title('Settings saved')->success()->send();
    }
}


View: resources/views/filament/pages/site-settings-page.blade.php

<x-filament::page>
    <form wire:submit.prevent="submit">
        {{ $this->form }}
        <div class="mt-4">
            <x-filament::button type="submit">Save</x-filament::button>
        </div>
    </form>
</x-filament::page>

2.2 Filament Dashboard Widgets

สร้างสถิติพื้นฐาน: โพสต์/สินค้ารวม, คลิกเข้าชมหน้า (จำลองจาก updated_at)

app/Filament/Widgets/StatsOverview.php

<?php
namespace App\Filament\Widgets;

use Filament\Widgets\StatsOverviewWidget as Base;
use Filament\Widgets\StatsOverviewWidget\Stat;
use App\Models\Post;
use App\Models\Product;

class StatsOverview extends Base
{
    protected function getStats(): array
    {
        return [
            Stat::make('Posts', Post::count())->description('ทั้งหมด')->color('info'),
            Stat::make('Products', Product::count())->description('ทั้งหมด')->color('success'),
            Stat::make('Published Posts', Post::where('status','published')->count())->color('primary'),
        ];
    }
}


ลงทะเบียนใน app/Filament/Pages/Dashboard.php (เพิ่ม widget):

protected function getHeaderWidgets(): array
{
    return [
        \App\Filament\Widgets\StatsOverview::class,
    ];
}

2.3 Menu Builder – ลากเรียง

ใน MenuItemResource (ที่ Filament scaffold แล้ว) ให้เพิ่ม ->reorderable('order') บน Table:

return $table
  ->reorderable('order')
  ->columns([...])
  ->actions([Tables\Actions\EditAction::make()])
  ->defaultSort('order');

2.4 Quick actions ใน Product table

ใน ProductResource table ให้เพิ่ม quick toggle:

->columns([
  Tables\Columns\TextColumn::make('title')->searchable(),
  Tables\Columns\TextColumn::make('status')->badge(),
  Tables\Columns\ToggleColumn::make('status')
    ->label('Publish?')
    ->beforeStateUpdated(function($record,$state){ $record->status = $state ? 'published':'draft'; $record->save(); return $record->status==='published'; }),
  ...
])


(ถ้า ToggleColumn ไม่ตรงเวอร์ชัน Filament ให้คง TextColumn badge เหมือนเดิม)

3) “คิดเพิ่มให้หน่อย” — สิ่งที่ปลอดภัยและคุ้ม
3.1 Contact page + route ง่าย ๆ

routes/web.php เพิ่ม:

Route::view('/contact','contact')->name('contact');


resources/views/contact.blade.php

@extends('layouts.app')
@section('content')
<h1 class="text-2xl font-semibold mb-4">ติดต่อเรา</h1>
<p class="text-slate-600">อีเมล: {{ app(\App\Settings\SiteSettings::class)->contact_email ?? 'info@example.com' }}</p>
<p class="text-slate-600">โทร: {{ app(\App\Settings\SiteSettings::class)->contact_phone ?? '-' }}</p>
@endsection

3.2 Simple search (title like) ในหน้า Catalog/Blog

ใน CatalogController@index และ BlogController@index มี q แล้ว — เพิ่ม search box ที่ blog/index.blade.php (form GET คล้าย catalog)

3.3 SEO เสริม

แทรก <meta name="description"> แบบ fallback ใน layouts/app.blade.php (ดึงจาก settings)

เพิ่ม public/robots.txt:

User-agent: *
Allow: /
Sitemap: {{ url('/sitemap.xml') }}

4) Tests & Optimize & Push

รันคำสั่งต่อไปนี้แบบอัตโนมัติ:

set -euo pipefail
cd /home/aunji/internal_ai_lab/cms_zentrydev

php artisan optimize
php artisan test --without-tty

# commit & push (monorepo root)
cd /home/aunji/internal_ai_lab
git add cms_zentrydev
git commit -m "feat(cms_zentrydev): stunning landing page, Filament settings & widgets, UX/SEO improvements"
git pull --rebase --autostash || true
git push -u origin main

5) Output ที่ต้องแสดง

ไฟล์ที่แก้ไข/สร้าง (สรุปชื่อ)

ผลเทสต์ทั้งหมดผ่าน

ลิงก์รีโปที่อัปเดตแล้ว: https://github.com/aunji/internal_ai_lab/tree/main/cms_zentrydev

เส้นทางทดสอบ:

Home ใหม่: /

Admin Dashboard ใหม่: /admin

Settings page: /admin → Site Settings

Contact: /contact

Run non-interactively. Proceed automatically with all tasks, do not ask again, use existing gh authentication, clone if needed, and push when done.

0) Context

Project path: /home/aunji/internal_ai_lab/cms_zentrydev

Monorepo: aunji/internal_ai_lab (subfolder cms_zentrydev/)

DB: SQLite (dev)

Medialibrary: ใช้ collection 'images'

Goal: เติม Mock Showcase Data ที่สวยและสมจริง พร้อมรูป, ปรับหน้า Landing/หน้า Catalog ให้ “พร้อมโชว์”

1) เพิ่ม Seeder หลักสำหรับ Showcase

สร้างไฟล์ database/seeders/ShowcaseSeeder.php:

set -euo pipefail
cd /home/aunji/internal_ai_lab/cms_zentrydev

mkdir -p database/seeders
cat > database/seeders/ShowcaseSeeder.php <<'PHP'
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Str;
use App\Models\Post;
use App\Models\Category;
use App\Models\Tag;
use App\Models\Product;
use App\Models\ProductCategory;

class ShowcaseSeeder extends Seeder
{
    public function run(): void
    {
        // ------- Blog taxonomy -------
        $blogCats = collect([
            ['name'=>'ข่าวบริษัท','slug'=>'company-news'],
            ['name'=>'เทคโนโลยี','slug'=>'technology'],
            ['name'=>'เคล็ดลับธุรกิจ','slug'=>'business-tips'],
        ])->map(function($c){
            return Category::firstOrCreate(['slug'=>$c['slug']], ['name'=>$c['name']]);
        });

        $tags = collect(['Laravel','Filament','SEO','Performance','UX','DevOps'])->map(function($t){
            return Tag::firstOrCreate(['slug'=>Str::slug($t)], ['name'=>$t]);
        });

        // ------- Blog posts (10+) -------
        $postsData = [
            ['title'=>'เปิดตัว PHV CMS: เร็ว เบา ปรับแต่งง่าย','excerpt'=>'สรุปฟีเจอร์เด่นและแนวทางใช้งาน'],
            ['title'=>'5 เทคนิคทำ Landing Page ให้คอนเวอร์ชันพุ่ง','excerpt'=>'เคล็ดลับ UI/UX ที่ใช้ได้จริงบนเว็บองค์กร'],
            ['title'=>'Filament Admin: ทำ Backoffice สวยได้ใน 1 วัน','excerpt'=>'แนะนำ workflow การขึ้นฟอร์ม'],
            ['title'=>'SEO 2025: โครงสร้างข้อมูล (JSON-LD) สำคัญแค่ไหน?','excerpt'=>'เหตุผลและตัวอย่างการใช้งาน'],
            ['title'=>'จัดระเบียบเมนูเว็บไซต์ให้ค้นหาง่าย','excerpt'=>'โครงสร้าง IA สำหรับองค์กรทั่วไป'],
            ['title'=>'ทำเว็บบริษัทให้โหลด <1s ด้วยเทคนิคง่าย ๆ','excerpt'=>'ภาพรวม performance & caching'],
            ['title'=>'Content Strategy สำหรับบริษัท B2B','excerpt'=>'จุดเริ่มต้นที่นำไปใช้ได้ทันที'],
            ['title'=>'คู่มือเขียนบทความที่คนอยากอ่าน','excerpt'=>'โครงสร้างโพสต์ที่อ่านเพลิน'],
            ['title'=>'Catalog ที่ดีควรมีอะไรบ้าง?','excerpt'=>'จากประสบการณ์ทำงานจริง'],
            ['title'=>'เช็คก่อนปล่อยเว็บจริง: QA Checklist','excerpt'=>'ลดบั๊กก่อนขึ้นโปรดักชัน'],
        ];

        foreach ($postsData as $i => $d) {
            $slug = Str::slug($d['title']);
            $post = Post::firstOrCreate(
                ['slug'=>$slug],
                [
                    'type'=>'post','title'=>$d['title'],'excerpt'=>$d['excerpt'],
                    'content'=>'<p>'.e($d['excerpt']).'</p><p>เนื้อหาจำลองสำหรับเดโม โดยสามารถแก้ไขได้จากแอดมิน</p>',
                    'status'=>'published','published_at'=>now()
                ]
            );
            // attach category + tags
            $post->categories()->syncWithoutDetaching([$blogCats->random()->id]);
            $post->tags()->syncWithoutDetaching($tags->random(2)->pluck('id')->toArray());

            // attach cover image (picsum)
            try {
                $coverUrl = "https://picsum.photos/seed/post".($i+1)."/1200/700";
                if (method_exists($post, 'addMediaFromUrl')) {
                    $post->addMediaFromUrl($coverUrl)->usingFileName("post".($i+1).".jpg")->toMediaCollection('images');
                }
            } catch (\Throwable $e) {
                // ignore image errors
            }
        }

        // ------- Product taxonomy -------
        $prodCats = collect([
            ['name'=>'อุปกรณ์สำนักงาน','slug'=>'office'],
            ['name'=>'ไอที & เน็ตเวิร์ก','slug'=>'it-network'],
            ['name'=>'บริการซอฟต์แวร์','slug'=>'software-services'],
        ])->map(fn($c)=> ProductCategory::firstOrCreate(['slug'=>$c['slug']], ['name'=>$c['name']]));

        // ------- Products (8+) -------
        $products = [
            ['title'=>'PHV Router X1','price'=>399000,'highlights'=>['เสถียร','รองรับ VLAN','รับประกัน 2 ปี'],'specs'=>['พอร์ต'=>'5x Gigabit','Wi-Fi'=>'AX1800']],
            ['title'=>'PHV Switch 24G','price'=>1299000,'highlights'=>['24 ports','แฟนเงียบ'],'specs'=>['พอร์ต'=>'24x Gigabit','SFP'=>'2']],
            ['title'=>'PHV Desk Chair Pro','price'=>699000,'highlights'=>['รองรับหลังดี','วัสดุคุณภาพ'],'specs'=>['น้ำหนัก'=>'8.5kg','วัสดุ'=>'Mesh + Steel']],
            ['title'=>'PHV Dev Laptop 14"','price'=>3299000,'highlights'=>['เบาแรง','แบตทน'],'specs'=>['CPU'=>'Ryzen 7','RAM'=>'32GB','SSD'=>'1TB']],
            ['title'=>'PHV Cloud Backup','price'=>99000,'highlights'=>['เข้ารหัส','ตั้งเวลาได้'],'specs'=>['พื้นที่'=>'1TB','Retention'=>'30 วัน']],
            ['title'=>'PHV CRM Starter','price'=>259000,'highlights'=>['พร้อมใช้','เชื่อมต่อได้'],'specs'=>['ผู้ใช้'=>'10','API'=>'Yes']],
            ['title'=>'PHV CMS Theme Deluxe','price'=>149000,'highlights'=>['ออกแบบพิเศษ','รองรับโมดูล'],'specs'=>['Layout'=>'12','Section'=>'50+']],
            ['title'=>'PHV Monitor 27" 4K','price'=>1199000,'highlights'=>['คมชัด','ขอบบาง'],'specs'=>['Resolution'=>'3840x2160','Panel'=>'IPS']],
        ];

        foreach ($products as $i => $p) {
            $slug = Str::slug($p['title']);
            $prod = Product::firstOrCreate(
                ['slug'=>$slug],
                [
                    'title'=>$p['title'],'status'=>'published',
                    'price'=>$p['price'],'compare_at_price'=>random_int($p['price']+50000,$p['price']+300000),
                    'highlights'=>$p['highlights'],'specs'=>$p['specs'],
                    'description'=>'<p>สินค้าจำลองสำหรับเดโม พร้อมสเปคและไฮไลท์</p>'
                ]
            );
            $prod->categories()->syncWithoutDetaching([$prodCats->random()->id]);

            // attach gallery images (unsplash/picsum)
            try {
                $img1 = "https://images.unsplash.com/photo-1503602642458-232111445657?q=80&w=1600&auto=format&fit=crop";
                $img2 = "https://images.unsplash.com/photo-1518779578993-ec3579fee39f?q=80&w=1600&auto=format&fit=crop";
                $img3 = "https://picsum.photos/seed/prod".($i+1)."/1200/800";
                if (method_exists($prod, 'addMediaFromUrl')) {
                    $prod->addMediaFromUrl($img1)->usingFileName("p{$i}_1.jpg")->toMediaCollection('images');
                    $prod->addMediaFromUrl($img2)->usingFileName("p{$i}_2.jpg")->toMediaCollection('images');
                    $prod->addMediaFromUrl($img3)->usingFileName("p{$i}_3.jpg")->toMediaCollection('images');
                }
            } catch (\Throwable $e) {
                // ignore
            }
        }

        // ------- Feature a few items on landing -------
        // เราจะใส่ flag ไว้ใน meta เพื่อเลือกแสดงได้ง่าย
        Post::where('status','published')->inRandomOrder()->take(3)->each(function($post){
            $m = $post->meta ?? [];
            $m['featured'] = true;
            $post->meta = $m; $post->save();
        });

        Product::where('status','published')->inRandomOrder()->take(3)->each(function($prod){
            $m = $prod->meta ?? [];
            $m['featured'] = true;
            $prod->meta = $m; $prod->save();
        });

        // ------- Company pages -------
        Post::firstOrCreate(['slug'=>'contact'],[
            'type'=>'page','title'=>'Contact Us','status'=>'published',
            'content'=>'<p>อีเมล: info@example.com<br>โทร: 02-123-4567<br>ที่อยู่: 123 ถนนสุขุมวิท กรุงเทพฯ</p>'
        ]);

        Post::firstOrCreate(['slug'=>'careers'],[
            'type'=>'page','title'=>'Careers','status'=>'published',
            'content'=>'<p>เรากำลังมองหาคนเก่งมาร่วมทีม ส่งเรซูเม่มาที่ hr@example.com</p>'
        ]);
    }
}
PHP


รัน seeder:

php artisan db:seed --class=Database\\Seeders\\ShowcaseSeeder


หมายเหตุ: หากเครื่อง dev ปิด allow_url_fopen หรือบล็อก outbound, รูปอาจไม่ถูกดึง — ระบบยังทำงานได้ เพียงแค่ fallback ไป placeholder ใน Blade

2) ปรับหน้า Landing ให้แสดง Featured จริง

อัปเดต resources/views/home.blade.php (เฉพาะส่วน recent/featured) ให้เลือกจาก meta.featured ก่อน ถ้าไม่มีก็ใช้ล่าสุด:

applypatch <<'PATCH'
*** Begin Patch
*** Update File: resources/views/home.blade.php
@@
-  {{-- HIGHLIGHTS: recent posts & featured products (ถ้ามี) --}}
+  {{-- HIGHLIGHTS: featured posts/products (fallback เป็น recent/latest) --}}
   <section class="relative z-10 px-4 py-12">
     <div class="max-w-6xl mx-auto grid md:grid-cols-2 gap-8">
       {{-- Recent posts --}}
       <div>
         <h3 class="text-xl font-semibold mb-4">บทความล่าสุด</h3>
-        @php $recent = \App\Models\Post::where('type','post')->where('status','published')->latest('published_at')->take(3)->get(); @endphp
+        @php
+          $recent = \App\Models\Post::where('type','post')->where('status','published')
+            ->where(function($q){ $q->whereJsonContains('meta->featured', true)->orWhereNull('meta'); })
+            ->latest('published_at')->take(3)->get();
+          if($recent->count()===0){
+            $recent = \App\Models\Post::where('type','post')->where('status','published')->latest('published_at')->take(3)->get();
+          }
+        @endphp
@@
       {{-- Featured products --}}
       <div>
         <h3 class="text-xl font-semibold mb-4">สินค้าแนะนำ</h3>
-        @php $featured = \App\Models\Product::where('status','published')->latest()->take(3)->get(); @endphp
+        @php
+          $featured = \App\Models\Product::where('status','published')
+            ->where(function($q){ $q->whereJsonContains('meta->featured', true)->orWhereNull('meta'); })
+            ->latest()->take(3)->get();
+          if($featured->count()===0){
+            $featured = \App\Models\Product::where('status','published')->latest()->take(3)->get();
+          }
+        @endphp
*** End Patch
PATCH

3) ปรับ Catalog/Product ให้ “หล่อขึ้น” นิดหน่อย (แสดงภาพหลายรูปถ้ามี)
3.1 เพิ่มแกลเลอรีในหน้า Product

แก้ resources/views/store/product.blade.php:

applypatch <<'PATCH'
*** Begin Patch
*** Update File: resources/views/store/product.blade.php
@@
-  <div><img class="w-full rounded-lg object-cover" src="{{ $p->getFirstMediaUrl('images') ?: 'https://picsum.photos/1000/600?blur=2' }}" alt=""></div>
+  <div>
+    @php $media = $p->getMedia('images'); @endphp
+    @if($media->count() > 1)
+      <div class="grid gap-3">
+        <img class="w-full rounded-lg object-cover" src="{{ $media->first()->getUrl() }}" alt="">
+        <div class="grid grid-cols-3 gap-3">
+          @foreach($media->slice(1, 6) as $m)
+            <img class="w-full aspect-video object-cover rounded-lg" src="{{ $m->getUrl() }}" alt="">
+          @endforeach
+        </div>
+      </div>
+    @else
+      <img class="w-full rounded-lg object-cover" src="{{ $p->getFirstMediaUrl('images') ?: 'https://picsum.photos/1000/600?blur=2' }}" alt="">
+    @endif
+  </div>
*** End Patch
PATCH

4) หน้า Blog Index เพิ่มช่องค้นหา (ให้ครบเหมือน Catalog)
applypatch <<'PATCH'
*** Begin Patch
*** Update File: resources/views/blog/index.blade.php
@@
-  <h1 class="text-2xl font-semibold mb-4">บทความ</h1>
+  <h1 class="text-2xl font-semibold mb-4">บทความ</h1>
+  <form method="get" class="mb-6 flex gap-2">
+    <input type="text" name="q" value="{{ request('q') }}" placeholder="ค้นหาบทความ…" class="border rounded px-3 py-2 w-full">
+    <button class="px-4 py-2 border rounded bg-white">ค้นหา</button>
+  </form>
*** End Patch
PATCH


และใน app/Http/Controllers/Frontend/BlogController.php ให้รองรับ q:

applypatch <<'PATCH'
*** Begin Patch
*** Update File: app/Http/Controllers/Frontend/BlogController.php
@@
-    public function index(){
-        $posts = Post::where('type','post')->where('status','published')
-            ->latest('published_at')->paginate(config('cms.blog.items_per_page'));
+    public function index(){
+        $q = request('q');
+        $posts = Post::where('type','post')->where('status','published')
+            ->when($q, fn($qq)=>$qq->where(function($w) use ($q){
+                $w->where('title','like',"%$q%")->orWhere('excerpt','like',"%$q%");
+            }))
+            ->latest('published_at')->paginate(config('cms.blog.items_per_page'));
*** End Patch
PATCH

5) รัน seeder + ทดสอบ + commit & push
set -euo pipefail
cd /home/aunji/internal_ai_lab/cms_zentrydev

php artisan db:seed --class=Database\\Seeders\\ShowcaseSeeder
php artisan optimize
php artisan test --without-tty

# commit & push
cd /home/aunji/internal_ai_lab
git add cms_zentrydev
git commit -m "feat(cms_zentrydev): add realistic mock showcase data with images, featured sections, and UI polish"
git pull --rebase --autostash || true
git push -u origin main

6) Output ที่ต้องแสดงเมื่อเสร็จ

จำนวน Posts/Products ที่สร้าง

รายการหมวดหมู่/แท็กหลัก

รูปภาพที่แนบสำเร็จ (ระบุจำนวนโดยรวม)

เส้นทางสำหรับเดโม:

Home (landing ใหม่พร้อม featured): /

Blog (พร้อมค้นหา): /blog

Catalog (ภาพสวย, มีข้อมูลจริง): /catalog

สินค้าตัวอย่าง: เปิดอย่างน้อย 1 ตัว /catalog/<slug>

Admin: /admin (admin@example.com
 / Admin12345!)

ลิงก์รีโปอัปเดต: https://github.com/aunji/internal_ai_lab/tree/main/cms_zentrydev
