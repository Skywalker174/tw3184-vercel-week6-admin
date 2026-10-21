import type { Metadata } from "next";
import "./globals.css";
export const metadata:Metadata={title:"Oddly Admin · TW3184 Week 6",description:"Restricted operations console for the Oddly Funny rating app.",robots:{index:false,follow:false}};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="en"><body>{children}</body></html>;}
