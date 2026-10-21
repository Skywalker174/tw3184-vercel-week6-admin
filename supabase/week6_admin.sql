begin;
alter table public.profiles add column if not exists is_superadmin boolean not null default false;
-- Existing profile upserts keep working, but role changes cannot be made by clients.
revoke insert,update on public.profiles from anon,authenticated;
grant insert(id,first_name,last_name,avatar_url,updated_at),update(id,first_name,last_name,avatar_url,updated_at) on public.profiles to authenticated;
create function public.protect_superadmin_flag() returns trigger language plpgsql set search_path='' as $$
begin
  if (new.is_superadmin and tg_op='INSERT') or (tg_op='UPDATE' and new.is_superadmin is distinct from old.is_superadmin) then
    if current_user not in ('postgres','supabase_admin','service_role') then raise exception 'Role changes require the database owner' using errcode='42501'; end if;
  end if;
  return new;
end $$;
create trigger protect_superadmin_flag before insert or update on public.profiles for each row execute function public.protect_superadmin_flag();
create function public.is_superadmin() returns boolean language sql stable security definer set search_path='' as $$
  select coalesce((auth.jwt()->'app_metadata'->>'provider')='google',false)
    and exists(select 1 from jsonb_array_elements(coalesce(auth.jwt()->'amr','[]'::jsonb)) a where a->>'method'='oauth')
    and exists(select 1 from public.profiles p where p.id=auth.uid() and p.is_superadmin);
$$;
revoke all on function public.is_superadmin() from public;
grant execute on function public.is_superadmin() to authenticated;
create function public.require_superadmin() returns void language plpgsql stable security definer set search_path='' as $$
begin if not public.is_superadmin() then raise exception 'Superadmin Google login required' using errcode='42501'; end if; end $$;
revoke all on function public.require_superadmin() from public;

create table public.admin_media_trash (
  id uuid primary key default gen_random_uuid(),
  media_id uuid not null,
  payload jsonb not null,
  deleted_by uuid references auth.users(id) on delete set null,
  deleted_at timestamptz not null default now(),
  restored_at timestamptz
);
create table public.admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  media_id uuid not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.admin_media_trash enable row level security;
alter table public.admin_audit_log enable row level security;
revoke all on public.admin_media_trash,public.admin_audit_log from anon,authenticated;

create function public.admin_overview() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
  perform public.require_superadmin();
  select jsonb_build_object(
    'profiles',(select count(*) from public.profiles),
    'media',(select count(*) from public.campus_captions),
    'ratings',(select count(*) from public.campus_votes),
    'upvotes',(select count(*) from public.campus_votes where value=1),
    'downvotes',(select count(*) from public.campus_votes where value=-1),
    'voters',(select count(distinct user_id) from public.campus_votes),
    'unrated',(select count(*) from public.campus_captions c where not exists(select 1 from public.campus_votes v where v.caption_id=c.id)),
    'incomplete_profiles',(select count(*) from public.profiles where nullif(trim(first_name),'') is null or nullif(trim(last_name),'') is null),
    'daily',(select coalesce(jsonb_agg(x order by x.day),'[]') from (
      select d::date as day,
      (select count(*) from public.campus_captions c where (c.created_at at time zone 'America/New_York')::date=d::date) as media,
      (select count(*) from public.campus_votes v where (v.created_at at time zone 'America/New_York')::date=d::date) as votes
      from generate_series((now() at time zone 'America/New_York')::date-13,(now() at time zone 'America/New_York')::date,interval '1 day') d
    ) x),
    'leaders',(select coalesce(jsonb_agg(x),'[]') from (
      select c.id,c.caption,count(v.id) as votes,coalesce(sum(v.value),0) as net,
      count(v.id) filter(where v.value=1) as upvotes,count(v.id) filter(where v.value=-1) as downvotes
      from public.campus_captions c left join public.campus_votes v on v.caption_id=c.id
      group by c.id order by coalesce(sum(v.value),0) desc,count(v.id) desc,c.created_at desc limit 4
    ) x),
    'models',(select coalesce(jsonb_agg(x),'[]') from (select model,count(*) as posts from public.campus_captions group by model order by count(*) desc) x)
  ) into result;
  return result;
end $$;

create function public.admin_list(p_section text,p_query text default '',p_page integer default 1) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare rows jsonb; total bigint; term text:='%'||left(coalesce(p_query,''),120)||'%'; skip integer:=(greatest(1,least(coalesce(p_page,1),10000))-1)*20;
begin
  perform public.require_superadmin();
  case p_section
  when 'profiles' then
    select count(*) into total from public.profiles p join auth.users u on u.id=p.id where concat_ws(' ',u.email,p.first_name,p.last_name) ilike term;
    select coalesce(jsonb_agg(x),'[]') into rows from (
      select p.id,u.email,p.first_name,p.last_name,p.created_at,p.is_superadmin,
      (select count(*) from public.campus_captions c where c.user_id=p.id) as posts,
      (select count(*) from public.campus_votes v where v.user_id=p.id) as votes
      from public.profiles p join auth.users u on u.id=p.id where concat_ws(' ',u.email,p.first_name,p.last_name) ilike term
      order by p.created_at desc,p.id limit 20 offset skip
    ) x;
  when 'media' then
    select count(*) into total from public.campus_captions c where concat_ws(' ',c.caption,c.scene,c.model) ilike term;
    select coalesce(jsonb_agg(x),'[]') into rows from (
      select c.*,u.email as author,
      (select count(*) from public.campus_votes v where v.caption_id=c.id and v.value=1) as upvotes,
      (select count(*) from public.campus_votes v where v.caption_id=c.id and v.value=-1) as downvotes
      from public.campus_captions c join auth.users u on u.id=c.user_id where concat_ws(' ',c.caption,c.scene,c.model) ilike term
      order by c.created_at desc,c.id limit 20 offset skip
    ) x;
  when 'ratings' then
    select count(*) into total from public.campus_votes v join public.campus_captions c on c.id=v.caption_id join auth.users u on u.id=v.user_id where concat_ws(' ',c.caption,u.email) ilike term;
    select coalesce(jsonb_agg(x),'[]') into rows from (
      select v.id,v.caption_id,v.value,v.created_at,c.caption,u.email as voter
      from public.campus_votes v join public.campus_captions c on c.id=v.caption_id join auth.users u on u.id=v.user_id where concat_ws(' ',c.caption,u.email) ilike term
      order by v.created_at desc,v.id limit 20 offset skip
    ) x;
  when 'trash' then
    select count(*) into total from public.admin_media_trash t where t.restored_at is null and t.payload->'post'->>'caption' ilike term;
    select coalesce(jsonb_agg(x),'[]') into rows from (
      select t.id,t.media_id,t.deleted_at,t.payload->'post'->>'caption' as caption,jsonb_array_length(t.payload->'votes') as votes
      from public.admin_media_trash t where t.restored_at is null and t.payload->'post'->>'caption' ilike term order by t.deleted_at desc limit 20 offset skip
    ) x;
  when 'audit' then
    select count(*) into total from public.admin_audit_log a where concat_ws(' ',a.action,a.media_id::text) ilike term;
    select coalesce(jsonb_agg(x),'[]') into rows from (
      select a.id,a.action,a.media_id,a.details,a.created_at,u.email as actor from public.admin_audit_log a left join auth.users u on u.id=a.actor_id
      where concat_ws(' ',a.action,a.media_id::text) ilike term order by a.created_at desc,a.id limit 20 offset skip
    ) x;
  else raise exception 'Unknown section' using errcode='22023';
  end case;
  return jsonb_build_object('rows',rows,'total',total);
end $$;

create function public.admin_media(p_operation text,p_data jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare target uuid; original public.campus_captions%rowtype; archived public.admin_media_trash%rowtype; backup jsonb; owner_id uuid;
begin
  perform public.require_superadmin();
  if p_operation in ('create','update') then
    if length(coalesce(p_data->>'scene','')) not between 12 and 500 or length(coalesce(p_data->>'caption','')) not between 1 and 1200
      or length(coalesce(p_data->>'prompt','')) not between 12 and 2000 or length(coalesce(p_data->>'model','')) not between 1 and 100 then
      raise exception 'Invalid media fields' using errcode='22023';
    end if;
  end if;
  if p_operation='create' then
    if not exists(select 1 from storage.objects where bucket_id='funny-images' and name=p_data->>'image_path') then raise exception 'Choose or upload a stored AI image' using errcode='22023'; end if;
    owner_id:=split_part(p_data->>'image_path','/',1)::uuid;
    insert into public.campus_captions(user_id,scene,caption,prompt,model,image_path)
      values(owner_id,p_data->>'scene',p_data->>'caption',p_data->>'prompt',p_data->>'model',p_data->>'image_path') returning id into target;
  elsif p_operation='update' then
    target:=(p_data->>'id')::uuid;
    select * into original from public.campus_captions where id=target for update;
    if not found then raise exception 'Media no longer exists' using errcode='P0002'; end if;
    if md5(row_to_json(original)::text) is distinct from p_data->>'version' then raise exception 'Another editor changed this post. Reload before saving.' using errcode='40001'; end if;
    update public.campus_captions set scene=p_data->>'scene',caption=p_data->>'caption',prompt=p_data->>'prompt',model=p_data->>'model' where id=target;
    backup:=jsonb_build_object('before',to_jsonb(original));
  elsif p_operation='delete' then
    target:=(p_data->>'id')::uuid;
    select * into original from public.campus_captions where id=target for update;
    if not found then raise exception 'Media no longer exists' using errcode='P0002'; end if;
    backup:=jsonb_build_object('post',to_jsonb(original),'votes',(select coalesce(jsonb_agg(v),'[]') from public.campus_votes v where v.caption_id=target),'bookmarks',(select coalesce(jsonb_agg(b),'[]') from public.caption_bookmarks b where b.caption_id=target));
    insert into public.admin_media_trash(media_id,payload,deleted_by) values(target,backup,auth.uid());
    delete from public.campus_captions where id=target;
  elsif p_operation='restore' then
    select * into archived from public.admin_media_trash where id=(p_data->>'id')::uuid and restored_at is null for update;
    if not found then raise exception 'Trash entry no longer available' using errcode='P0002'; end if;
    target:=archived.media_id;
    insert into public.campus_captions select * from jsonb_populate_record(null::public.campus_captions,archived.payload->'post');
    insert into public.campus_votes select * from jsonb_populate_recordset(null::public.campus_votes,archived.payload->'votes') on conflict do nothing;
    insert into public.caption_bookmarks select * from jsonb_populate_recordset(null::public.caption_bookmarks,archived.payload->'bookmarks') on conflict do nothing;
    update public.admin_media_trash set restored_at=now() where id=archived.id;
  else raise exception 'Unknown operation' using errcode='22023';
  end if;
  insert into public.admin_audit_log(actor_id,action,media_id,details) values(auth.uid(),p_operation,target,case when p_operation='update' then backup else '{}'::jsonb end);
  return target;
end $$;

-- Detail version is generated in SQL for optimistic concurrency, not trusted from the UI.
create function public.admin_media_detail(p_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
  perform public.require_superadmin();
  select to_jsonb(c)||jsonb_build_object('version',md5(row_to_json(c)::text)) into result from public.campus_captions c where id=p_id;
  return result;
end $$;
revoke all on function public.admin_overview(),public.admin_list(text,text,integer),public.admin_media(text,jsonb),public.admin_media_detail(uuid) from public;
grant execute on function public.admin_overview(),public.admin_list(text,text,integer),public.admin_media(text,jsonb),public.admin_media_detail(uuid) to authenticated;
-- Recycle-bin images remain restorable; the original owner cannot remove their bytes.
create function public.media_path_in_use(p_path text) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.campus_captions c where c.image_path=p_path)
    or exists(select 1 from public.admin_media_trash t where t.restored_at is null and t.payload->'post'->>'image_path'=p_path);
$$;
revoke all on function public.media_path_in_use(text) from public;
grant execute on function public.media_path_in_use(text) to authenticated;
alter policy "Remove own unpublished image" on storage.objects
using(bucket_id='funny-images' and (storage.foldername(name))[1]=(select auth.uid())::text and not public.media_path_in_use(name));
commit;
