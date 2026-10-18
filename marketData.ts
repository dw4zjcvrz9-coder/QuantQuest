export type Quote = { symbol: string; price: number; changePct: number; asOf: string; marketOpen?: boolean; provider?: string };

export interface MarketDataProvider { quotes(symbols: string[]): Promise<Quote[]> }

const seed: Record<string, [number, number]> = { AAPL:[227.16,1.24], MSFT:[414.71,-0.38], NVDA:[182.08,2.81], SPY:[642.69,0.44] };

export class DemoMarketData implements MarketDataProvider {
  async quotes(symbols: string[]) { return symbols.map(symbol => { const [price, changePct] = seed[symbol] ?? [100,0]; return {symbol,price,changePct,asOf:new Date().toISOString()}; }); }
}

export class ServerMarketData implements MarketDataProvider {
  constructor(private baseUrl:string) {}
  async quotes(symbols:string[]) {
    const unique=[...new Set(symbols.map(symbol=>symbol.trim().toUpperCase()).filter(Boolean))].slice(0,10);
    const response=await fetch(`${this.baseUrl.replace(/\/$/,'')}/quotes?symbols=${encodeURIComponent(unique.join(','))}`,{headers:{accept:'application/json'}});
    const body=await response.json().catch(()=>({}));
    if(!response.ok) throw new Error(body.message||'Market data unavailable');
    return Array.isArray(body)?body:body.quotes??[];
  }
}
