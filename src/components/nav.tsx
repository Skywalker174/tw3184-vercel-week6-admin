"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
export function Nav(){const path=usePathname();return <nav aria-label="Admin sections">{[{path:"/",icon:"◫",label:"Overview"},{path:"/profiles",icon:"◎",label:"Users & profiles"},{path:"/media",icon:"▧",label:"AI media"},{path:"/ratings",icon:"⇅",label:"Ratings"},{path:"/trash",icon:"↺",label:"Recycle bin"},{path:"/audit",icon:"≡",label:"Audit log"}].map(item=><Link key={item.path} href={item.path} aria-current={item.path==="/"?path==="/"?"page":undefined:path.startsWith(item.path)?"page":undefined}><span aria-hidden="true">{item.icon}</span>{item.label}</Link>)}</nav>;}
