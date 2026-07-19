-- Doodoo MVP: prompt catalog, filtering, publishing, and analytics.
-- Image binaries live in Cloudflare R2. `image_key` stores only the R2 object key.

create extension if not exists pgcrypto;

create type public.prompt_status as enum ('draft', 'published', 'archived');
create type public.prompt_event_type as enum ('view', 'copy');

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  name text not null check (char_length(trim(name)) > 0),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.sub_options (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories (id) on delete cascade,
  slug text not null check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  name text not null check (char_length(trim(name)) > 0),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (category_id, slug),
  unique (id, category_id)
);

create table public.tags (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  name text not null check (char_length(trim(name)) > 0),
  group_name text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

CREATE TABLE public.prompts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  
  -- 1. 다국어 지원을 위해 JSONB 타입으로 변경
  title jsonb NOT NULL,
  summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  
  category_id uuid NOT NULL REFERENCES public.categories (id) ON DELETE RESTRICT,
  sub_option_id uuid,
  base_prompt text NOT NULL CHECK (char_length(trim(base_prompt)) > 0),
  edit_fields jsonb NOT NULL DEFAULT '[]'::jsonb,
  
  -- 2. 기존 image_key를 썸네일과 프리뷰 경로로 분리 및 제약조건 적용
  image_thumbnail_key text NOT NULL CHECK (image_thumbnail_key !~ '^/' AND char_length(trim(image_thumbnail_key)) > 0),
  image_preview_key text NOT NULL CHECK (image_preview_key !~ '^/' AND char_length(trim(image_preview_key)) > 0),
  
  image_alt text NOT NULL DEFAULT '',
  status public.prompt_status NOT NULL DEFAULT 'draft',
  published_at timestamptz,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  
  -- 3. 고도화된 JSONB 타입 정밀 검증 제약 조건들
  CONSTRAINT prompts_title_is_object CHECK (jsonb_typeof(title) = 'object'),
  CONSTRAINT prompts_summary_is_object CHECK (jsonb_typeof(summary) = 'object'),
  CONSTRAINT prompts_edit_fields_is_array CHECK (jsonb_typeof(edit_fields) = 'array'),
  
  -- 상태 및 날짜 매칭 제약 조건
  CONSTRAINT prompts_published_at_matches_status CHECK (
    (status = 'published' AND published_at IS NOT NULL)
    OR (status IN ('draft', 'archived') AND published_at IS NULL)
  ),
  -- 카테고리-서브옵션 복합 외래키 제약 조건
  CONSTRAINT prompts_sub_option_in_category FOREIGN KEY (sub_option_id, category_id)
    REFERENCES public.sub_options (id, category_id) ON DELETE RESTRICT
);

create table public.prompt_tags (
  prompt_id uuid not null references public.prompts (id) on delete cascade,
  tag_id uuid not null references public.tags (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (prompt_id, tag_id)
);

create table public.prompt_events (
  id bigint generated always as identity primary key,
  prompt_id uuid not null references public.prompts (id) on delete cascade,
  event_type public.prompt_event_type not null,
  created_at timestamptz not null default now()
);

create index categories_active_sort_order_idx
  on public.categories (sort_order, name) where is_active;
create index sub_options_category_active_sort_order_idx
  on public.sub_options (category_id, sort_order, name) where is_active;
create index tags_active_group_name_idx
  on public.tags (group_name, name) where is_active;
create index prompts_published_category_sort_order_idx
  on public.prompts (category_id, sort_order, published_at desc)
  where status = 'published';
create index prompts_published_sub_option_sort_order_idx
  on public.prompts (sub_option_id, sort_order, published_at desc)
  where status = 'published' and sub_option_id is not null;
create index prompt_tags_tag_prompt_idx on public.prompt_tags (tag_id, prompt_id);
create index prompt_events_prompt_event_created_at_idx
  on public.prompt_events (prompt_id, event_type, created_at desc);

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger categories_set_updated_at
before update on public.categories
for each row execute function public.set_updated_at();

create trigger sub_options_set_updated_at
before update on public.sub_options
for each row execute function public.set_updated_at();

create trigger tags_set_updated_at
before update on public.tags
for each row execute function public.set_updated_at();

create trigger prompts_set_updated_at
before update on public.prompts
for each row execute function public.set_updated_at();

alter table public.categories enable row level security;
alter table public.sub_options enable row level security;
alter table public.tags enable row level security;
alter table public.prompts enable row level security;
alter table public.prompt_tags enable row level security;
alter table public.prompt_events enable row level security;

create policy "Public can read active categories"
on public.categories for select to anon, authenticated
using (is_active);

create policy "Public can read active sub options"
on public.sub_options for select to anon, authenticated
using (is_active);

create policy "Public can read active tags"
on public.tags for select to anon, authenticated
using (is_active);

create policy "Public can read published prompts"
on public.prompts for select to anon, authenticated
using (
  status = 'published' and published_at <= now()
);

create policy "Public can read tags for published prompts"
on public.prompt_tags for select to anon, authenticated
using (
  exists (
    select 1
    from public.prompts
    where prompts.id = prompt_id
      and prompts.status = 'published'
      and prompts.published_at <= now()
  )
);

grant usage on schema public to anon, authenticated;
grant select on public.categories, public.sub_options, public.tags, public.prompts, public.prompt_tags
  to anon, authenticated;
