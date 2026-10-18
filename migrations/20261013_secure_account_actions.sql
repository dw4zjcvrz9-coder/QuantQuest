-- QuantQuest: make portfolio-changing actions server-authoritative.
-- Apply this migration before deploying the account-action Edge Function.

create or replace function public.qq_execute_trade(
  p_user_id uuid,
  p_side text,
  p_symbol text,
  p_price numeric,
  p_max_position_pct numeric default 20
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_portfolio public.portfolios%rowtype;
  v_position public.positions%rowtype;
  v_shares integer;
  v_total integer;
  v_avg numeric;
  v_cost numeric;
  v_trade_id uuid := gen_random_uuid();
begin
  if p_side not in ('BUY','SELL') then raise exception 'Invalid side'; end if;
  if p_symbol !~ '^[A-Z][A-Z0-9.-]{0,9}$' then raise exception 'Invalid symbol'; end if;
  if p_price <= 0 then raise exception 'Invalid market price'; end if;
  if p_max_position_pct < 1 or p_max_position_pct > 100 then raise exception 'Invalid position size'; end if;

  select * into v_portfolio from public.portfolios where user_id=p_user_id for update;
  if not found then raise exception 'Portfolio not found'; end if;

  select * into v_position from public.positions where user_id=p_user_id and symbol=p_symbol for update;

  if p_side='BUY' then
    -- Position size is based on server-stored equity/cash, never a client-supplied balance.
    v_shares := floor(least(v_portfolio.cash, v_portfolio.equity * p_max_position_pct / 100) / p_price);
    if v_shares < 1 then raise exception 'Not enough paper cash'; end if;
    v_cost := round(v_shares * p_price, 2);
    if v_cost > v_portfolio.cash then raise exception 'Not enough paper cash'; end if;

    if v_position.user_id is null then
      insert into public.positions(user_id,symbol,shares,avg_price,updated_at)
      values(p_user_id,p_symbol,v_shares,p_price,now());
      v_total := v_shares; v_avg := p_price;
    else
      v_total := v_position.shares + v_shares;
      v_avg := ((v_position.shares*v_position.avg_price)+(v_shares*p_price))/v_total;
      update public.positions set shares=v_total,avg_price=v_avg,updated_at=now()
      where user_id=p_user_id and symbol=p_symbol;
    end if;

    update public.portfolios set cash=cash-v_cost,xp=xp+15,updated_at=now() where user_id=p_user_id;
  else
    if v_position.user_id is null then raise exception 'Nothing to sell'; end if;
    v_shares := v_position.shares;
    v_cost := round(v_shares * p_price, 2);
    delete from public.positions where user_id=p_user_id and symbol=p_symbol;
    update public.portfolios set cash=cash+v_cost,xp=xp+15,updated_at=now() where user_id=p_user_id;
  end if;

  insert into public.trades(id,user_id,side,symbol,shares,price,created_at)
  values(v_trade_id,p_user_id,p_side,p_symbol,v_shares,p_price,now());

  return jsonb_build_object('id',v_trade_id,'side',p_side,'symbol',p_symbol,'shares',v_shares,'price',p_price);
end;
$$;

create or replace function public.qq_claim_daily_reward(p_user_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_portfolio public.portfolios%rowtype; v_prizes integer[]:=array[100,150,200,250,500]; v_prize integer;
begin
  select * into v_portfolio from public.portfolios where user_id=p_user_id for update;
  if not found then raise exception 'Portfolio not found'; end if;
  if v_portfolio.last_reward_date=current_date then raise exception 'Reward already claimed'; end if;
  v_prize:=v_prizes[1+floor(random()*array_length(v_prizes,1))::int];
  update public.portfolios set cash=cash+v_prize,xp=xp+25,last_reward_date=current_date,updated_at=now() where user_id=p_user_id;
  return jsonb_build_object('prize',v_prize,'date',current_date);
end; $$;

create or replace function public.qq_reset_account(p_user_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  delete from public.positions where user_id=p_user_id;
  delete from public.trades where user_id=p_user_id;
  delete from public.portfolio_snapshots where user_id=p_user_id;
  update public.portfolios set cash=10000,equity=10000,xp=0,last_reward_date=null,updated_at=now() where user_id=p_user_id;
  insert into public.portfolio_snapshots(user_id,equity,captured_at) values(p_user_id,10000,now());
end; $$;

create or replace function public.qq_set_equity(p_user_id uuid,p_equity numeric)
returns void language plpgsql security definer set search_path=public as $$
begin
  if p_equity < 0 then raise exception 'Invalid equity'; end if;
  update public.portfolios set equity=round(p_equity,2),updated_at=now() where user_id=p_user_id;
end; $$;

-- Only the Edge Function's service role may mutate financial state through these functions.
revoke all on function public.qq_execute_trade(uuid,text,text,numeric,numeric) from public, anon, authenticated;
revoke all on function public.qq_claim_daily_reward(uuid) from public, anon, authenticated;
revoke all on function public.qq_reset_account(uuid) from public, anon, authenticated;
revoke all on function public.qq_set_equity(uuid,numeric) from public, anon, authenticated;
grant execute on function public.qq_execute_trade(uuid,text,text,numeric,numeric) to service_role;
grant execute on function public.qq_claim_daily_reward(uuid) to service_role;
grant execute on function public.qq_reset_account(uuid) to service_role;
grant execute on function public.qq_set_equity(uuid,numeric) to service_role;

-- Clients may read their data, but can no longer forge balances, positions, trades, or snapshots.
drop policy if exists "Users can update their portfolio" on public.portfolios;
drop policy if exists "Users manage their positions" on public.positions;
drop policy if exists "Users manage their trades" on public.trades;
drop policy if exists "Users manage their snapshots" on public.portfolio_snapshots;

create policy "Users read own positions" on public.positions for select to authenticated using(auth.uid()=user_id);
create policy "Users read own trades" on public.trades for select to authenticated using(auth.uid()=user_id);
create policy "Users read own snapshots" on public.portfolio_snapshots for select to authenticated using(auth.uid()=user_id);

revoke update on public.portfolios from authenticated;
revoke insert,update,delete on public.positions from authenticated;
revoke insert,update,delete on public.trades from authenticated;
revoke insert,update,delete on public.portfolio_snapshots from authenticated;
