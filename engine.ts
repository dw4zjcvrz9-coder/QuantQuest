export type Strategy='Momentum'|'Mean Reversion'|'Moving Average'|'RSI'|'Breakout'|'MACD'|'Bollinger Bands';
export type Rules={maxPositionPct:number; stopLossPct:number; takeProfitPct:number; symbol:string};
export function signal(strategy:Strategy, prices:number[]):'BUY'|'SELL'|'HOLD'{
  if(prices.length<5)return'HOLD'; const latest=prices.at(-1)!; const avg=prices.reduce((a,b)=>a+b,0)/prices.length;
  if(strategy==='Momentum') return latest>prices[0]*1.02?'BUY':latest<prices[0]*.98?'SELL':'HOLD';
  if(strategy==='Mean Reversion') return latest<avg*.98?'BUY':latest>avg*1.02?'SELL':'HOLD';
  const short=prices.slice(-3).reduce((a,b)=>a+b,0)/3;
  if(strategy==='Moving Average')return short>avg*1.003?'BUY':short<avg*.997?'SELL':'HOLD';
  if(strategy==='Breakout'){
    const prior=prices.slice(0,-1);return latest>Math.max(...prior)?'BUY':latest<Math.min(...prior)?'SELL':'HOLD';
  }
  if(strategy==='MACD')return short>avg*1.004?'BUY':short<avg*.996?'SELL':'HOLD';
  if(strategy==='Bollinger Bands'){
    const deviation=Math.sqrt(prices.reduce((sum,value)=>sum+(value-avg)**2,0)/prices.length);
    return latest<avg-1.5*deviation?'BUY':latest>avg+1.5*deviation?'SELL':'HOLD';
  }
  const changes=prices.slice(1).map((value,index)=>value-prices[index]);
  const gains=changes.reduce((sum,value)=>sum+Math.max(0,value),0)/changes.length;
  const losses=changes.reduce((sum,value)=>sum+Math.max(0,-value),0)/changes.length;
  const rsi=losses===0?100:100-(100/(1+gains/losses));
  return rsi<35?'BUY':rsi>65?'SELL':'HOLD';
}
export function maxOrderValue(equity:number,rules:Rules){return Math.max(0,equity*rules.maxPositionPct/100)}
