import Link from "next/link";
import { list,type Media } from "@/lib/admin";
import { MediaEditor } from "@/components/media-forms";
export default async function NewMedia(){const {rows}=await list<Media>("media");return <main className="content"><Link className="back" href="/media">← Content library</Link><div className="pageHead"><div><p className="eyebrow">CREATE</p><h1>Give an AI asset a home.</h1><p>Register generated media with its original prompts and model provenance.</p></div></div><MediaEditor assets={rows}/></main>;}
