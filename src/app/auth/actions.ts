"use server";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/db";
export async function signIn(){
  const origin=process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : "http://localhost:3001";
  const db=await createClient();
  const {data,error}=await db.auth.signInWithOAuth({provider:"google",options:{redirectTo:`${origin}/auth/callback`}});
  if(error||!data.url) redirect("/login?error=1");
  redirect(data.url);
}
export async function signOut(){const db=await createClient();await db.auth.signOut();redirect("/login");}
