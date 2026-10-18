import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors={
  'Access-Control-Allow-Origin':'*',
  'Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type',
};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,'content-type':'application/json'}});
const symbolOk=(s:string)=>/^[A-Z][A-Z0-9.-]{0,9}$/.test(s);

Deno.serve(async(req)=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
  try{
    const auth=req.headers.get('Authorization');
    if(!auth)return json({message:'Unauthorized'},401);
    const url=Deno.env.get('SUPABASE_URL')!;
    const anon=Deno.env.get('SUPABASE_ANON_KEY')!;
    const service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const market=(Deno.env.get('MARKET_DATA_URL')||'').replace(/\/$/,'');
    if(!market)return json({message:'MARKET_DATA_URL is not configured'},500);

    const userClient=createClient(url,anon,{global:{headers:{Authorization:auth}}});
    const {data:{user},error:userError}=await userClient.auth.getUser();
    if(userError||!user)return json({message:'Unauthorized'},401);
    const admin=createClient(url,service,{auth:{persistSession:false}});
    const body=await req.json().catch(()=>({}));
    const action=String(body.action||'');

    const fetchQuotes=async(symbols:string[])=>{
      const unique=[...new Set(symbols.map(s=>s.trim().toUpperCase()).filter(symbolOk))].slice(0,10);
      if(!unique.length)return [] as any[];
      const response=await fetch(`${market}/quotes?symbols=${encodeURIComponent(unique.join(','))}`,{headers:{accept:'application/json'}});
      const payload=await response.json().catch(()=>({}));
      if(!response.ok)throw new Error(payload.message||'Market data unavailable');
      return (Array.isArray(payload)?payload:payload.quotes||[]) as any[];
    };

    const syncEquity=async()=>{
      const [{data:portfolio,error:pError},{data:positions,error:posError}]=await Promise.all([
        admin.from('portfolios').select('cash').eq('user_id',user.id).single(),
        admin.from('positions').select('symbol,shares,avg_price').eq('user_id',user.id),
      ]);
      if(pError)throw pError;if(posError)throw posError;
      const rows=positions||[];
      const quotes=await fetchQuotes(rows.map((p:any)=>p.symbol));
      const prices=new Map(quotes.map((q:any)=>[q.symbol,Number(q.price)]));
      const equity=Number(portfolio.cash)+rows.reduce((sum:number,p:any)=>sum+Number(p.shares)*(prices.get(p.symbol)??Number(p.avg_price)),0);
      const {error}=await admin.rpc('qq_set_equity',{p_user_id:user.id,p_equity:equity});if(error)throw error;
      const {error:snapshotError}=await admin.from('portfolio_snapshots').insert({user_id:user.id,equity,captured_at:new Date().toISOString()});
      if(snapshotError)throw snapshotError;
      return equity;
    };

    if(action==='trade'){
      const side=String(body.side||'').toUpperCase();
      const symbol=String(body.symbol||'').trim().toUpperCase();
      const pct=Math.min(100,Math.max(1,Number(body.maxPositionPct)||20));
      if(!['BUY','SELL'].includes(side)||!symbolOk(symbol))return json({message:'Invalid order'},400);
      const quotes=await fetchQuotes([symbol]);
      const quote=quotes.find((q:any)=>q.symbol===symbol);
      if(!quote||!(Number(quote.price)>0))return json({message:'No current market price'},503);
      const {data,error}=await admin.rpc('qq_execute_trade',{p_user_id:user.id,p_side:side,p_symbol:symbol,p_price:Number(quote.price),p_max_position_pct:pct});
      if(error)throw error;
      const equity=await syncEquity();
      return json({trade:data,equity});
    }
    if(action==='reward'){
      const {data,error}=await admin.rpc('qq_claim_daily_reward',{p_user_id:user.id});if(error)throw error;
      const equity=await syncEquity();return json({reward:data,equity});
    }
    if(action==='reset'){
      const {error}=await admin.rpc('qq_reset_account',{p_user_id:user.id});if(error)throw error;
      return json({ok:true,equity:10000});
    }
    if(action==='sync_equity')return json({equity:await syncEquity()});
    return json({message:'Unknown action'},400);
  }catch(error){return json({message:error instanceof Error?error.message:'Request failed'},400)}
});
