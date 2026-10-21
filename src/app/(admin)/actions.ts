"use server";
import { randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/lib/admin";
export type State={message:string;ok?:boolean;id?:string};
export async function saveMedia(_:State,form:FormData):Promise<State>{
  const {db,user}=await requireAdmin();
  const operation=form.get("operation")==="update"?"update":"create";
  const scene=String(form.get("scene")??"").trim(),caption=String(form.get("caption")??"").trim(),prompt=String(form.get("prompt")??"").trim(),model=String(form.get("model")??"").trim();
  if(scene.length<12||scene.length>500||!caption||caption.length>1200||prompt.length<12||prompt.length>2000||!model||model.length>100)return {message:"Check the field lengths before saving."};
  if(operation==="create"&&form.get("provenance")!=="yes")return {message:"Confirm that the asset is AI generated and the prompt/model metadata is accurate."};
  let path=String(form.get("image_path")??""),uploaded:string|null=null;
  if(operation==="create"){
    const file=form.get("image");
    if(file instanceof File&&file.size>0){
      const types:Record<string,string>={"image/jpeg":"jpg","image/png":"png","image/webp":"webp"};
      if(file.size>5*1024*1024||!types[file.type])return {message:"Use a JPEG, PNG or WebP image under 5 MB."};
      path=`${user.id}/${randomUUID()}.${types[file.type]}`;
      const {error}=await db.storage.from("funny-images").upload(path,file,{contentType:file.type,upsert:false});
      if(error)return {message:"The image upload failed. No media record was created."};
      uploaded=path;
    }
    if(!path)return {message:"Choose an existing AI image or upload one."};
  }
  const {data,error}=await db.rpc("admin_media",{p_operation:operation,p_data:{id:form.get("id"),version:form.get("version"),scene,caption,prompt,model,image_path:path}});
  if(error){
    if(uploaded)await db.storage.from("funny-images").remove([uploaded]);
    return {message:error.code==="40001"?"Another editor changed this post. Reload before saving.":"Media could not be saved. Check your role and the field values, then retry."};
  }
  revalidatePath("/", "layout");
  return {ok:true,id:String(data),message:operation==="create"?"AI media registered. Creation recorded in the audit log.":"Changes saved and audited. Existing votes were retained."};
}
export async function moveToTrash(_:State,form:FormData):Promise<State>{
  const {db}=await requireAdmin();
  if(form.get("confirmation")!=="TRASH")return {message:"Type TRASH to confirm."};
  const {error}=await db.rpc("admin_media",{p_operation:"delete",p_data:{id:form.get("id")}});
  if(error)return {message:"Could not move this record. Refresh and try again."};
  revalidatePath("/","layout");
  return {ok:true,message:"Moved to the recycle bin. Media, votes and bookmarks can be restored."};
}
export async function restoreMedia(_:State,form:FormData):Promise<State>{
  const {db}=await requireAdmin();
  const {error}=await db.rpc("admin_media",{p_operation:"restore",p_data:{id:form.get("id")}});
  if(error)return {message:"Restore failed. The record may already exist or its original account may be unavailable."};
  revalidatePath("/","layout");
  return {ok:true,message:"Restored with its original votes and bookmarks."};
}
