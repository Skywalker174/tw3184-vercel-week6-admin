import Link from "next/link";
import { notFound } from "next/navigation";
import { list,requireAdmin,date,pageNumber,type Profile,type Rating,type Trash,type Audit } from "@/lib/admin";
import { Search,Pages,Empty } from "@/components/list";
import { Restore } from "@/components/media-forms";
export default async function Section({params,searchParams}:{params:Promise<{section:string}>;searchParams:Promise<{q?:string;page?:string}>}){
  await requireAdmin();
  const {section}=await params,{q="",page:p}=await searchParams,page=pageNumber(p);
  if(!["profiles","ratings","trash","audit"].includes(section))notFound();
  const title={profiles:"The people behind the votes.",ratings:"Every vote has a record.",trash:"A second chance for content.",audit:"Nothing changes quietly."}[section as "profiles"];
  const {rows,total}=await list<Profile|Rating|Trash|Audit>(section,q,page);
  return <main className="content"><div className="pageHead"><div><p className="eyebrow">{section.toUpperCase()}</p><h1>{title}</h1><p>{section==="profiles"?"Read-only profiles. Roles are managed only by the database owner.":section==="ratings"?"Read-only ratings. No score inflation, edits or deleted votes.":section==="trash"?"Restore deleted media with its original votes and bookmarks.":"Who changed what, and when. All times shown in New York."}</p></div><span className="pill">{section==="trash"?"RECOVERABLE":"READ ONLY"}</span></div><Search q={q} total={total} label={section}/>
    {!rows.length?<Empty/>:<div className="tableWrap"><table>
      <thead><tr>{(section==="profiles"?["User","Role","Joined","Media","Votes"]:section==="ratings"?["Rating","AI media","Voter","Recorded"]:section==="trash"?["Media","Deleted","Saved ratings","Action"]:["Action","Media ID","Actor","Recorded","Details"]).map(h=><th key={h}>{h}</th>)}</tr></thead>
      <tbody>{rows.map(record=>{
        if(section==="profiles"){const r=record as Profile;return <tr key={r.id}><td><strong>{[r.first_name,r.last_name].filter(Boolean).join(" ")||"Name not provided"}</strong><small>{r.email}</small><code>{r.id.slice(0,8)}…</code></td><td><span className={r.is_superadmin?"pill accent":"pill"}>{r.is_superadmin?"Superadmin":"Member"}</span></td><td>{date(r.created_at)}</td><td>{r.posts}</td><td>{r.votes}</td></tr>;}
        if(section==="ratings"){const r=record as Rating;return <tr key={r.id}><td><span className={r.value===1?"pill positive":"pill negative"}>{r.value===1?"↑ Upvote":"↓ Downvote"}</span></td><td><Link href={`/media/${r.caption_id}`}>{r.caption}</Link><small>{r.caption_id.slice(0,8)}…</small></td><td>{r.voter}</td><td>{date(r.created_at)}</td></tr>;}
        if(section==="trash"){const r=record as Trash;return <tr key={r.id}><td><strong>{r.caption}</strong><small>{r.media_id}</small></td><td>{date(r.deleted_at)}</td><td>{r.votes}</td><td><Restore id={r.id}/></td></tr>;}
        const r=record as Audit;return <tr key={r.id}><td><span className="pill">{r.action}</span></td><td><Link href={`/media/${r.media_id}`}>{r.media_id.slice(0,8)}…</Link></td><td>{r.actor??"Account unavailable"}</td><td>{date(r.created_at)}</td><td><details><summary>Inspect</summary><pre>{JSON.stringify(r.details,null,2)}</pre></details></td></tr>;
      })}</tbody></table></div>}<Pages page={page} total={total} q={q}/>
  </main>;
}
