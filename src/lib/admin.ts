import "server-only";
import { cache } from "react";
import { redirect } from "next/navigation";
import { createClient } from "./db";
export const requireAdmin = cache(async () => {
  const db=await createClient();
  const {data:{user},error}=await db.auth.getUser();
  if(error || !user) redirect("/login");
  if(user.app_metadata.provider!=="google") redirect("/login?denied=1");
  const {data:allowed,error:roleError}=await db.rpc("is_superadmin");
  if(roleError || allowed!==true) redirect("/login?denied=1");
  return {db,user};
});
export type Media = {id:string;scene:string;caption:string;prompt:string;model:string;image_path:string|null;created_at:string;author?:string;upvotes?:number;downvotes?:number;version?:string};
export type Profile = {id:string;email:string;first_name:string|null;last_name:string|null;is_superadmin:boolean;created_at:string;posts:number;votes:number};
export type Rating = {id:string;caption_id:string;caption:string;voter:string;value:number;created_at:string};
export type Trash = {id:string;media_id:string;caption:string;deleted_at:string;votes:number};
export type Audit = {id:string;action:string;media_id:string;actor:string;created_at:string;details:Record<string,unknown>};
export type Overview = {profiles:number;media:number;ratings:number;upvotes:number;downvotes:number;voters:number;unrated:number;incomplete_profiles:number;daily:{day:string;media:number;votes:number}[];leaders:{id:string;caption:string;votes:number;net:number;upvotes:number;downvotes:number}[];models:{model:string;posts:number}[]};
export async function list<T>(section:string,q="",page=1):Promise<{rows:T[];total:number}> {
  const {db}=await requireAdmin();
  const {data,error}=await db.rpc("admin_list",{p_section:section,p_query:q.slice(0,120),p_page:page});
  if(error) throw new Error("Admin data could not be loaded. Refresh or try again shortly.");
  return data as {rows:T[];total:number};
}
export async function overview():Promise<Overview> {
  const {db}=await requireAdmin();
  const {data,error}=await db.rpc("admin_overview");
  if(error) throw new Error("Statistics are temporarily unavailable.");
  return data as Overview;
}
export async function mediaDetail(id:string):Promise<Media|null> {
  const {db}=await requireAdmin();
  if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) return null;
  const {data,error}=await db.rpc("admin_media_detail",{p_id:id});
  if(error) throw new Error("Media could not be loaded.");
  return data as Media|null;
}
export const date=(value:string)=>new Date(value).toLocaleString("en-US",{timeZone:"America/New_York",dateStyle:"medium",timeStyle:"short"});
export function pageNumber(value?:string) { return Math.min(10000,Math.max(1,Number.parseInt(value??"1",10)||1)); }
