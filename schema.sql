create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.portfolios (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  cash numeric(14,2) not null default 10000,
  equity numeric(14,2) not null default 10000,
  xp integer not null default 0,
  last_reward_date date,
  updated_at timestamptz not null default now()
);

create table if not exists public.positions (
  user_id uuid not null references public.profiles(id) on delete cascade,
  symbol text not null,
  shares integer not null check (shares > 0),
  avg_price numeric(14,4) not null check (avg_price > 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, symbol)
);

create table if not exists public.trades (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  side text not null check (side in ('BUY', 'SELL')),
  symbol text not null,
  shares integer not null check (shares > 0),
  price numeric(14,4) not null check (price > 0),
  created_at timestamptz not null default now()
);

create table if not exists public.portfolio_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  equity numeric(14,2) not null,
  captured_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.portfolios enable row level security;
alter table public.positions enable row level security;
alter table public.trades enable row level security;
alter table public.portfolio_snapshots enable row level security;

drop policy if exists "Signed-in users can view profiles" on public.profiles;
create policy "Signed-in users can view profiles" on public.profiles for select to authenticated using (true);
drop policy if exists "Users can update their profile" on public.profiles;
create policy "Users can update their profile" on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);
drop policy if exists "Signed-in users can view leaderboard portfolios" on public.portfolios;
create policy "Signed-in users can view leaderboard portfolios" on public.portfolios for select to authenticated using (true);
drop policy if exists "Users can update their portfolio" on public.portfolios;
create policy "Users can update their portfolio" on public.portfolios for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "Users manage their positions" on public.positions;
create policy "Users manage their positions" on public.positions for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "Users manage their trades" on public.trades;
create policy "Users manage their trades" on public.trades for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "Users manage their snapshots" on public.portfolio_snapshots;
create policy "Users manage their snapshots" on public.portfolio_snapshots for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, username) values (new.id, 'Trader-' || left(new.id::text, 6));
  insert into public.portfolios (user_id) values (new.id);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace view public.leaderboard with (security_invoker = true) as
select dense_rank() over (order by portfolios.equity desc, portfolios.xp desc) as rank,
  profiles.id, profiles.username, portfolios.equity, portfolios.xp
from public.profiles join public.portfolios on portfolios.user_id = profiles.id;

grant select, update on public.profiles to authenticated;
grant select, update on public.portfolios to authenticated;
grant select, insert, update, delete on public.positions to authenticated;
grant select, insert, update, delete on public.trades to authenticated;
grant select, insert, update, delete on public.portfolio_snapshots to authenticated;
grant select on public.leaderboard to authenticated;
