#!/bin/bash
set -e
echo "🔧 Generating Hunter Forex Mobile (Termux Fixed)..."

mkdir -p app/{api/{signals,chart,cron,alert/telegram},lib,components}

# 1. package.json (+ Tailwind/PostCSS)
cat > package.json << 'PKG'
{"name":"hunter-forex-mobile","version":"1.0.0","private":true,"scripts":{"dev":"next dev","build":"next build","start":"next start"},"dependencies":{"next":"14.2.5","react":"^18","react-dom":"^18","lightweight-charts":"^4.1.3","@upstash/redis":"^1.28.0","tailwindcss":"^3.4.1","postcss":"^8","autoprefixer":"^10"},"devDependencies":{"@types/node":"^20","@types/react":"^18","typescript":"^5"}}
PKG

# 2. tailwind.config.ts
cat > tailwind.config.ts << 'TWC'
import type { Config } from "tailwindcss";
const config: Config = { content: ["./app/**/*.{js,ts,jsx,tsx,mdx}","./components/**/*.{js,ts,jsx,tsx,mdx}"], theme: { extend: {} }, plugins: [] };
export default config;
TWC

# 3. postcss.config.mjs
cat > postcss.config.mjs << 'PC'
const config = { plugins: { tailwindcss: {}, autoprefixer: {} } };
export default config;
PC

# 4. globals.css (FIX @tailwind error)
cat > app/globals.css << 'CSS'
@tailwind base;
@tailwind components;
@tailwind utilities;

html { touch-action: manipulation; font-size: 14px; }
CSS

# 5. tsconfig.json
cat > tsconfig.json << 'TSC'
{"compilerOptions":{"target":"ES2017","lib":["dom","dom.iterable","esnext"],"allowJs":true,"skipLibCheck":true,"strict":true,"noEmit":true,"esModuleInterop":true,"module":"esnext","moduleResolution":"bundler","resolveJsonModule":true,"isolatedModules":true,"jsx":"preserve","incremental":true,"plugins":[{"name":"next"}],"paths":{"@/*":["./*"]}},"include":["next-env.d.ts","**/*.ts","**/*.tsx",".next/types/**/*.ts"],"exclude":["node_modules"]}
TSC

# 6. next.config.ts
cat > next.config.ts << 'NX'
import type { NextConfig } from "next";
const nextConfig: NextConfig = { reactStrictMode: true };
export default nextConfig;
NX
# 7. .env.local
cat > .env.local << 'ENV'
TWELVE_DATA_API_KEY=
UPSTASH_REDIS_REST_URL=
UPSTASH_REDIS_REST_TOKEN=
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=
ENV

# 8. vercel.json
cat > vercel.json << 'VJ'
{"crons":[{"path":"/api/cron","schedule":"*/5 * * * 1-5"}]}
VJ

# 9. app/layout.tsx
cat > app/layout.tsx << 'LAY'
import type { Metadata } from "next"; import "@/app/globals.css";
export const metadata: Metadata = { title: "Hunter Forex Mobile", viewport: "width=device-width, initial-scale=1, maximum-scale=1" };
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (<html lang="en"><body className="bg-slate-950 text-slate-200 antialiased">{children}</body></html>);
}
LAY

# 10. app/page.tsx
cat > app/page.tsx << 'PAGE'
"use client"; import { useState, useEffect } from 'react'; import Chart from '@/components/Chart'; import { CandlestickData } from 'lightweight-charts';
export default function Home() {
  const [sig, setSig] = useState<any>(null); const [cd, setCd] = useState<CandlestickData[]>([]); const [busy, setBusy] = useState(false);
  const run = async () => { setBusy(true); try {
    const [s,c] = await Promise.all([fetch('/api/signals').then(r=>r.json()), fetch('/api/chart').then(r=>r.json())]);
    if(s.success) setSig(s.data); if(c.success) setCd(c.data);
    fetch('/api/alert/telegram').catch(()=>{});
  } finally { setBusy(false); } };
  useEffect(() => { run(); }, []);
  return (<main className="min-h-screen bg-slate-950 text-slate-200 p-4 space-y-4 max-w-md mx-auto">
    <div className="flex justify-between items-center"><h1 className="text-lg font-bold text-white">🎯 Hunter Mobile</h1><button onClick={run} disabled={busy} className="px-3 py-1.5 bg-blue-600 rounded text-sm">{busy?'Scanning...':'🔄 Sync'}</button></div>
    <div className="w-full h-[280px] border border-slate-800 rounded-lg overflow-hidden bg-slate-900"><Chart data={cd} /></div>
    {sig && (<div className="bg-slate-900 p-3 rounded border border-slate-800 space-y-2"><div className="flex justify-between"><span className="font-bold">{sig.pair} | {sig.tf}</span><span className={sig.dir==='BUY'?'text-green-400':'text-red-400'}>{sig.dir}</span></div><div className="grid grid-cols-2 gap-2 text-xs"><p>Entry: <span className="text-yellow-300">{sig.entry}</span></p><p>SL: <span className="text-red-400">{sig.sl}</span> ({sig.lot} Lot)</p><p>TP: <span className="text-green-400">{sig.tp}</span> | RR: {sig.rr}</p><p>Conf: {sig.conf}%</p></div><p className="text-[10px] text-slate-500">{sig.reasons.join(' • ')}</p></div>)}</main>);
}
PAGE

# 11. lib/risk.ts
cat > lib/risk.ts << 'RISK'
export interface RiskResult { sl: number; tp: number; rr: number; lotSize: number; slPips: number; }
export function calculateRisk(entry: number, atr: number, direction: 'BUY' | 'SELL', minRR: number, balance: number, riskPct: number, pair: string): RiskResult {
  const slDist = atr * 1.5;
  const sl = direction === 'BUY' ? entry - slDist : entry + slDist;
  const tp = direction === 'BUY' ? entry + slDist * minRR : entry - slDist * minRR;
  const isJPY = pair.includes('JPY'); const isXAU = pair.includes('XAU');
  const pipSize = isXAU ? 0.1 : (isJPY ? 0.01 : 0.0001);  const slPips = slDist / pipSize;
  let pipVal = 10.0;
  if (isXAU) pipVal = 1.0;
  else if (!pair.endsWith('USD')) pipVal = 10.0;
  const riskAmt = balance * riskPct;
  let lot = riskAmt / (slPips * pipVal);
  lot = Math.max(0.01, Math.min(50, Math.round(lot * 100) / 100));
  return { sl, tp, rr: minRR, lotSize: lot, slPips: Math.round(slPips) };
}
RISK

# 12. lib/cache.ts
cat > lib/cache.ts << 'CACH'
import { Redis } from '@upstash/redis';
const redis = new Redis({ url: process.env.UPSTASH_REDIS_REST_URL || '', token: process.env.UPSTASH_REDIS_REST_TOKEN || '' });
export const getCache = (k: string) => redis.get(k);
export const setCache = (k: string, v: string, ttl: number) => redis.setex(k, ttl, v);
CACH

# 13. lib/engine.ts
cat > lib/engine.ts << 'ENG'
import { getCache, setCache } from './cache'; import { calculateRisk } from './risk';
const KEY = process.env.TWELVE_DATA_API_KEY || '';
const BASE = 'https://api.twelvedata.com/time_series';
export async function getSignal(pair = 'EURUSD', tf = 'H1', bal = 10000, rPct = 0.01) {
  const ck = `sig:${pair}:${tf}`; const cached = await getCache(ck); if (cached) return JSON.parse(cached);
  const r = await fetch(`${BASE}?symbol=${pair}&interval=${tf.toLowerCase()}&outputsize=50&apikey=${KEY}`);
  const j = await r.json(); if (j.status !== 'ok' || !j.values) throw new Error(j.message || 'Fetch fail');
  const d = j.values.reverse(); const c = d.map((x:any)=>+x.close), h=d.map((x:any)=>+x.high), l=d.map((x:any)=>+x.low);
  const price = c[c.length-1]; const e50=ema(c,50), e200=ema(c,200), rsi=calcRSI(c,14), atr=calcATR(h,l,c,14);
  let score=0; const reasons:string[]=[];
  if(e50>e200){score+=30;reasons.push('EMA Bull');}else{score+=30;reasons.push('EMA Bear');}
  if(rsi>45&&rsi<65){score+=20;reasons.push(`RSI N (${rsi.toFixed(1)})`);}else{score+=10;reasons.push(`RSI ${rsi>=65?'OB':'OS'}`);}
  if(atr>0.0005){score+=15;reasons.push('ATR Active');}
  const dir = e50>e200?'BUY':'SELL'; const risk = calculateRisk(price, atr, dir, 2.0, bal, rPct, pair);
  const sig = {pair,tf,dir,entry:price,sl:risk.sl,tp:risk.tp,rr:risk.rr,conf:Math.min(100,score),reasons,lot:risk.lotSize,pips:risk.slPips,ts:new Date().toISOString()};
  await setCache(ck, JSON.stringify(sig), 300); return sig;
}
function calcRSI(c:number[],p=14):number{if(c.length<p+1)return 50;let g=0,l=0;for(let i=1;i<=p;i++){const d=c[i]-c[i-1];d>0?g+=d:l-=d;}g/=p;l/=p;for(let i=p+1;i<c.length;i++){const d=c[i]-c[i-1];g=(g*(p-1)+(d>0?d:0))/p;l=(l*(p-1)+(d<0?-d:0))/p;}const rs=l===0?100:g/l;return 100-(100/(1+rs));}
function calcATR(h:number[],l:number[],c:number[],p=14):number{const tr=[];for(let i=1;i<c.length;i++)tr.push(Math.max(h[i]-l[i],Math.abs(h[i]-c[i-1]),Math.abs(l[i]-c[i-1])));if(!tr.length)return 0;let a=tr.slice(0,p).reduce((s,v)=>s+v,0)/p;for(let i=p;i<tr.length;i++)a=(a*(p-1)+tr[i])/p;return a;}
function ema( number[],p:number):number{const k=2/(p+1);let v=data[0];for(let i=1;i<data.length;i++)v=data[i]*k+v*(1-k);return v;}
ENG

# 14. components/Chart.tsx
cat > components/Chart.tsx << 'CHART'
"use client"; import { useEffect, useRef } from 'react'; import { createChart, ColorType, CandlestickData } from 'lightweight-charts';
export default function Chart({ data }: {  CandlestickData[] }) {
  const box = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!box.current || !data.length) return;    const ch = createChart(box.current, { layout:{background:{type:ColorType.Solid,color:'#0f172a'},textColor:'#94a3b8'},width:box.current.clientWidth,height:300,grid:{vertLines:{color:'#1e293b'},horzLines:{color:'#1e293b'}}});
    const s = ch.addCandlestickSeries({upColor:'#22c55e',downColor:'#ef4444',borderVisible:false,wickUpColor:'#22c55e',wickDownColor:'#ef4444'});
    s.setData(data.sort((a,b)=>(a.time as string).localeCompare(b.time as string))); ch.timeScale().fitContent();
    const onRes = () => ch.applyOptions({width:box.current!.clientWidth}); window.addEventListener('resize', onRes);
    return () => { window.removeEventListener('resize', onRes); ch.remove(); };
  }, [data]);
  return <div ref={box} className="w-full h-full" />;
}
CHART

# 15. API Routes
cat > app/api/signals/route.ts << 'ASIG'
import { NextResponse } from 'next/server'; import { getSignal } from '@/lib/engine';
export const dynamic = 'force-dynamic';
export async function GET() { try { const s = await getSignal('EURUSD','H1',10000,0.01); return NextResponse.json({success:true,data:s}); } catch(e:any){return NextResponse.json({success:false,error:e.message},{status:500});} }
ASIG

cat > app/api/chart/route.ts << 'ACHART'
import { NextResponse } from 'next/server'; export const dynamic = 'force-dynamic';
export async function GET() { const r = await fetch(`https://api.twelvedata.com/time_series?symbol=EURUSD&interval=h1&outputsize=50&apikey=${process.env.TWELVE_DATA_API_KEY}`); const j = await r.json(); if(j.status!=='ok'||!j.values) return NextResponse.json({success:false,data:[]}); const d = j.values.reverse().map((x:any)=>({time:x.datetime,open:+x.open,high:+x.high,low:+x.low,close:+x.close})); return NextResponse.json({success:true,data:d}); }
ACHART

cat > app/api/cron/route.ts << 'ACRON'
import { NextResponse } from 'next/server'; export const dynamic = 'force-dynamic';
export async function GET() { await fetch(`${process.env.VERCEL_URL||'http://localhost:3000'}/api/signals`).catch(()=>{}); await fetch(`${process.env.VERCEL_URL||'http://localhost:3000'}/api/alert/telegram`).catch(()=>{}); return NextResponse.json({ok:true}); }
ACRON

cat > app/api/alert/telegram/route.ts << 'ATEL'
import { NextResponse } from 'next/server'; export const dynamic = 'force-dynamic';
export async function GET() { try { const t=process.env.TELEGRAM_BOT_TOKEN, c=process.env.TELEGRAM_CHAT_ID; if(!t||!c) return NextResponse.json({skip:true}); await fetch(`https://api.telegram.org/bot${t}/sendMessage`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({chat_id:c,text:`🎯 *Hunter Signal Updated*\n⏰ ${new Date().toLocaleTimeString()}\n📊 Open dashboard for details.`,parse_mode:'Markdown'})}).catch(()=>{}); return NextResponse.json({success:true}); } catch(e:any){return NextResponse.json({success:false,error:e.message},{status:500});} }
ATEL

echo "✅ Struktur selesai. Install dependencies..."
npm install --legacy-peer-deps
echo "🚀 Ready. Edit .env.local → npx vercel --prod"
