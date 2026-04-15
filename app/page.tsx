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
