"use client";
import { useEffect, useRef } from 'react';
import { createChart, CandlestickData } from 'lightweight-charts';

export default function Chart({ data }: { data: CandlestickData[] }) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!ref.current || !data.length) return;
    const chart = createChart(ref.current, {
      width: ref.current.clientWidth,
      height: 280,
      layout: { background: { color: '#0f172a' }, textColor: '#94a3b8' },
      grid: { vertLines: { color: '#1e293b' }, horzLines: { color: '#1e293b' } },
    });
    const series = chart.addCandlestickSeries();
    series.setData(data);
    chart.timeScale().fitContent();
    return () => chart.remove();
  }, [data]);

  return <div ref={ref} className="w-full h-full" />;
}
