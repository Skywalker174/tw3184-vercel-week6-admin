"use client";
export default function AdminError({reset}:{reset:()=>void}){return <main className="content"><section className="panel"><p className="eyebrow">TEMPORARILY UNAVAILABLE</p><h1>Let’s try that again.</h1><p>The admin data request could not be completed. No unconfirmed changes are shown.</p><button className="primary" onClick={reset}>Retry</button></section></main>;}
