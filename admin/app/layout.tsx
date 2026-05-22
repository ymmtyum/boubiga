import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "boubiga Admin",
  description: "boubiga server config admin",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ja">
      <body>{children}</body>
    </html>
  );
}
