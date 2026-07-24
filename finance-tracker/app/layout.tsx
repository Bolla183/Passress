import type { Metadata, Viewport } from "next";
import { Geist } from "next/font/google";
import "./globals.css";
import BottomNav from "@/components/BottomNav";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Passress Finance",
  description: "Expense and revenue tracker for Passress",
  appleWebApp: {
    title: "Passress",
    statusBarStyle: "black-translucent",
  },
};

// viewportFit: "cover" is required for env(safe-area-inset-*) to resolve to
// the actual notch/home-indicator insets in the installed PWA -- without it
// they're always 0, and fixed-bottom UI (BottomNav, the floating Add button)
// sits flush under the iOS home-indicator gesture area.
export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${geistSans.variable} h-full antialiased`}>
      <body className="min-h-full flex flex-col bg-paper text-ink">
        <div className="flex-1 pb-[calc(5rem+env(safe-area-inset-bottom))]">{children}</div>
        <BottomNav />
      </body>
    </html>
  );
}
