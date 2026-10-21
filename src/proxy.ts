import { createServerClient } from "@supabase/ssr";
import { NextResponse,type NextRequest } from "next/server";
export async function proxy(request:NextRequest) {
  let response=NextResponse.next({request});
  const db=createServerClient(process.env.SUPABASE_URL!,process.env.SUPABASE_ANON_KEY!,{cookies:{getAll:()=>request.cookies.getAll(),setAll(items){items.forEach(({name,value})=>request.cookies.set(name,value));response=NextResponse.next({request});items.forEach(({name,value,options})=>response.cookies.set(name,value,options));}}});
  await db.auth.getClaims();
  return response;
}
export const config={matcher:["/((?!_next/static|_next/image|favicon.ico).*)"]};
