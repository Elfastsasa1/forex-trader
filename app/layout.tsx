import type { Metadata } from "next"; import "@/app/globals.css";
export const metadata: Metadata = { title: "Hunter Forex Mobile", viewport: "width=device-width, initial-scale=1, maximum-scale=1" };
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (<html lang="en"><body className="bg-slate-950 text-slate-200 antialiased">{children}</body></html>);
}
