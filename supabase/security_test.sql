-- Run as the database owner after approving ONE bootstrap administrator.
-- All writes, including test media/votes/bookmarks, are rolled back.
begin;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select id from public.profiles where not is_superadmin order by created_at limit 1),'app_metadata',jsonb_build_object('provider','google'))::text,true);
set local role authenticated;
do $$ begin
  if public.is_superadmin() then raise exception 'Ordinary member passed role gate'; end if;
  begin perform public.admin_overview(); raise exception 'Overview leaked'; exception when insufficient_privilege then null; end;
  begin perform public.admin_list('profiles'); raise exception 'Profiles leaked'; exception when insufficient_privilege then null; end;
  begin perform public.admin_media('create','{}'); raise exception 'Unauthorized write'; exception when insufficient_privilege then null; end;
  begin update public.profiles set is_superadmin=true where id=auth.uid(); raise exception 'Self promotion succeeded'; exception when insufficient_privilege then null; end;
  -- Existing Week 3 profile upserts must keep working after narrowing grants.
  insert into public.profiles(id,first_name,last_name,avatar_url,updated_at)
  values(auth.uid(),'Rollback','Test',null,now()) on conflict(id) do update
    set id=excluded.id,first_name=excluded.first_name,last_name=excluded.last_name,avatar_url=excluded.avatar_url,updated_at=excluded.updated_at;
  if public.is_superadmin() then raise exception 'Profile upsert changed role'; end if;
end $$;
set local role postgres;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select id from public.profiles where is_superadmin limit 1),'app_metadata',jsonb_build_object('provider','email'))::text,true);
set local role authenticated;
do $$ begin
  if public.is_superadmin() then raise exception 'Non-Google login passed'; end if;
  begin perform public.admin_overview(); raise exception 'Non-Google admin leaked'; exception when insufficient_privilege then null; end;
end $$;
set local role postgres;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select id from public.profiles where is_superadmin limit 1),'app_metadata',jsonb_build_object('provider','google'))::text,true);
set local role authenticated;
do $$ declare source jsonb; post_id uuid; detail jsonb; trash_id uuid; old_version text;
begin
  if not public.is_superadmin() then raise exception 'Approved Google admin denied'; end if;
  perform public.admin_overview(); perform public.admin_list('profiles'); perform public.admin_list('ratings');
  select item into source from jsonb_array_elements(public.admin_list('media')->'rows') item where item->>'image_path' is not null limit 1;
  if source is null then raise exception 'Need an existing AI image for rollback CRUD test'; end if;
  post_id:=public.admin_media('create',jsonb_build_object('scene','Week six rollback test scene.','caption','Week six rollback test caption.','prompt','Week six rollback provenance test.','model',source->>'model','image_path',source->>'image_path'));
  detail:=public.admin_media_detail(post_id); old_version:=detail->>'version';
  perform public.admin_media('update',detail||jsonb_build_object('caption','Updated rollback caption.'));
  begin perform public.admin_media('update',detail); raise exception 'Stale update succeeded'; exception when serialization_failure then null; end;
  insert into public.campus_votes(user_id,caption_id,value) values(auth.uid(),post_id,1);
  insert into public.caption_bookmarks(user_id,caption_id) values(auth.uid(),post_id);
  begin update public.campus_votes set value=-1 where caption_id=post_id; raise exception 'Rating edited'; exception when insufficient_privilege then null; end;
  perform public.admin_media('delete',jsonb_build_object('id',post_id));
  if public.admin_media_detail(post_id) is not null then raise exception 'Media not deleted'; end if;
  select (item->>'id')::uuid into trash_id from jsonb_array_elements(public.admin_list('trash')->'rows') item where item->>'media_id'=post_id::text;
  if trash_id is null then raise exception 'Recycle bin backup missing'; end if;
  perform public.admin_media('restore',jsonb_build_object('id',trash_id));
  if public.admin_media_detail(post_id)->>'caption'<>'Updated rollback caption.' then raise exception 'Restore content mismatch'; end if;
  if not exists(select 1 from public.campus_votes where caption_id=post_id and user_id=auth.uid()) then raise exception 'Vote not restored'; end if;
  if not exists(select 1 from public.caption_bookmarks where caption_id=post_id and user_id=auth.uid()) then raise exception 'Bookmark not restored'; end if;
  perform public.admin_list('audit');
end $$;
set local role postgres;
select set_config('request.jwt.claims','{}',true);
set local role anon;
do $$ begin
  begin perform public.admin_overview(); raise exception 'Anonymous overview access'; exception when insufficient_privilege then null; end;
  begin perform public.admin_list('profiles'); raise exception 'Anonymous profiles access'; exception when insufficient_privilege then null; end;
  begin perform public.admin_media('delete','{}'); raise exception 'Anonymous mutation access'; exception when insufficient_privilege then null; end;
end $$;
set local role postgres;
select 'PASS: member and anonymous denied; self-promotion denied; Google required; profile upsert preserved; admin CRUD + restore + votes/bookmarks + concurrency passed' as verification;
rollback;
