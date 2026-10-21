import { NextResponse } from "next/server";
import { createClient } from "@/lib/db";
export async function GET(request:Request){
  const url=new URL(request.url),code=url.searchParams.get("code");
  if(!code)return NextResponse.redirect(new URL("/login?error=1",url.origin));
  const db=await createClient();
  const {error}=await db.auth.exchangeCodeForSession(code);
  if(error)return NextResponse.redirect(new URL("/login?error=1",url.origin));
  const {data:{user}}=await db.auth.getUser();
  const {data:allowed}=await db.rpc("is_superadmin");
  return NextResponse.redirect(new URL(user?.app_metadata.provider==="google" && allowed===true ? "/" : "/login?denied=1",url.origin));
}
