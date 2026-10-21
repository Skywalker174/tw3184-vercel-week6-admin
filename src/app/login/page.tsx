import { createClient } from "@/lib/db";
import { redirect } from "next/navigation";
import { signIn,signOut } from "../auth/actions";
export default async function Login({searchParams}:{searchParams:Promise<{denied?:string;error?:string}>}){
  const params=await searchParams,db=await createClient();
  const {data:{user}}=await db.auth.getUser();
  if(user?.app_metadata.provider==="google"){const {data}=await db.rpc("is_superadmin");if(data===true)redirect("/");}
  return <main className="login"><section><div className="mark">O<span>↗</span></div><p className="eyebrow">TW3184 · WEEK 6 / RESTRICTED ACCESS</p><h1>Good content.<br/>Careful operations.</h1><p className="lede">The admin workspace for Oddly Funny. Google sign-in and a database-approved superadmin role are both required.</p>
    {params.denied&&<p className="notice" role="alert">Access denied. This account is not an approved Google superadmin. No admin data has been loaded.</p>}
    {params.error&&<p className="notice" role="alert">Sign-in could not be completed. Please try again.</p>}
    {user ? <form action={signOut}><button className="primary">Sign out & switch account</button></form> : <form action={signIn}><button className="primary">Continue with Google →</button></form>}
    <p className="fine">A public sign-in page does not mean a public database. Ordinary users cannot grant themselves admin access.</p><a href="https://week-1-hello-world-vercel.vercel.app/campus">← Back to the rating app</a>
  </section><aside><span>PRIVATE BY DESIGN</span><h2>One workspace.<br/>Every signal.</h2><p>Understand the audience.<br/>Curate the media.<br/>Keep the audit trail.</p><div className="loginArt" aria-hidden="true"><i/><i/><i/><i/><i/><i/></div><small>GOOGLE AUTH + DATABASE ROLE + AUDITED MUTATIONS</small></aside></main>;
}
