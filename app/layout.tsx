import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Executive PPM | Portfolio Command Centre",
  description: "Executive project portfolio management and weekly reporting."
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
