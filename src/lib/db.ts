import "server-only";
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
export async function createClient() {
  const jar = await cookies();
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_ANON_KEY;
  if (!url || !key) throw new Error("Supabase environment is missing");
  return createServerClient(url,key,{cookies:{getAll:()=>jar.getAll(),setAll(items){try{items.forEach(({name,value,options})=>jar.set(name,value,options));}catch{/* Proxy handles refresh in Server Components. */}}}});
}
