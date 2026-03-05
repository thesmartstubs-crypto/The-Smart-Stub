-- Run this in your Supabase SQL editor

create table if not exists public.tokens (
  id           bigserial primary key,
  token_id     text unique not null,
  status       text not null default 'unused'  -- 'unused' | 'claimed' | 'revoked'
               check (status in ('unused', 'claimed', 'revoked')),
  event_data   jsonb,                           -- null = blank token
  created_by   uuid references auth.users(id),  -- admin who generated it
  claimed_by   uuid references auth.users(id),  -- user who activated it
  claimed_at   timestamptz,
  stub_id      bigint references public.stubs(id), -- stub created on activation
  created_at   timestamptz default now()
);

-- Index for fast token lookups
create index if not exists tokens_token_id_idx on public.tokens(token_id);
create index if not exists tokens_status_idx   on public.tokens(status);
create index if not exists tokens_claimed_by_idx on public.tokens(claimed_by);

-- RLS: anyone can read a token by token_id (needed for activation page)
alter table public.tokens enable row level security;

create policy "Public can read tokens by token_id"
  on public.tokens for select
  using (true);

create policy "Authenticated users can claim tokens"
  on public.tokens for update
  using (auth.uid() is not null)
  with check (status = 'claimed' and claimed_by = auth.uid());

create policy "Admins can insert tokens"
  on public.tokens for insert
  with check (auth.uid() is not null);

-- Refresh schema cache
notify pgrst, 'reload schema';
