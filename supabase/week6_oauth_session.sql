-- Safe incremental hardening for databases that already applied week6_admin.sql.
-- Google identity metadata alone is insufficient; the session must include OAuth AMR.
create or replace function public.is_superadmin() returns boolean language sql stable security definer set search_path='' as $$
  select coalesce((auth.jwt()->'app_metadata'->>'provider')='google',false)
    and exists(select 1 from jsonb_array_elements(coalesce(auth.jwt()->'amr','[]'::jsonb)) a where a->>'method'='oauth')
    and exists(select 1 from public.profiles p where p.id=auth.uid() and p.is_superadmin);
$$;
revoke all on function public.is_superadmin() from public;
grant execute on function public.is_superadmin() to authenticated;
