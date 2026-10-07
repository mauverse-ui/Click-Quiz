begin;
alter table public.cq_attempts add column if not exists experiment_id bigint references public.cq_fashion_experiments(id);
create or replace function public.cq_resolve_fashion(p_requested text,p_bucket integer)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v text; c public.cq_fashion_release; ex public.cq_fashion_experiments; answer jsonb; eid bigint;
begin
 if p_bucket is null or p_bucket not between 0 and 99 then raise exception 'Invalid allocation';end if;
 if p_requested is not null then v=p_requested;else
 select * into c from public.cq_fashion_release where singleton;v=c.default_version;
 if c.experiment_id is not null then
 select * into ex from public.cq_fashion_experiments where id=c.experiment_id and status='running';
 if found then eid=ex.id;v=case when p_bucket<50 then ex.control_version else ex.candidate_version end;end if;
 end if;end if;
 select content into answer from public.cq_versions where version=v and content->>'kind'='preferences';
 if answer is null then raise exception 'Edition unavailable';end if;
 return answer||jsonb_build_object('allocation',eid);
end $$;
create or replace function public.cq_record_fashion_events(p_attempt uuid,p_version text,p_referral uuid,p_source_ref uuid,p_attribution jsonb,p_events jsonb,p_experiment bigint)
returns void language plpgsql security definer set search_path='' as $$begin
 perform public.cq_record_events(p_attempt,p_version,p_referral,p_source_ref,p_attribution,p_events);
 if p_experiment is not null and p_source_ref is null and exists(select 1 from public.cq_fashion_experiments where id=p_experiment and status='running' and p_version in(control_version,candidate_version)) then
 update public.cq_attempts set experiment_id=p_experiment where id=p_attempt and experiment_id is null;
 end if;
end $$;
revoke all on function public.cq_record_fashion_events(uuid,text,uuid,uuid,jsonb,jsonb,bigint) from public,anon,authenticated;
grant execute on function public.cq_record_fashion_events(uuid,text,uuid,uuid,jsonb,jsonb,bigint) to anon,authenticated;

create or replace function public.cq_register_candidate(p_manifest jsonb,p_hypothesis text)
returns bigint language plpgsql security definer set search_path='' as $$
declare current_v text; candidate_v text; q jsonb; o jsonb; eid bigint;
begin
 select default_version into current_v from public.cq_fashion_release where singleton for update;
 if (public.cq_fashion_report(current_v)->>'settled_starts')::int<200 then raise exception 'Insufficient sample: 200 settled starts required';end if;
 candidate_v=p_manifest->>'version';
 if candidate_v is null or candidate_v !~ '^fashion-[a-z0-9-]{1,60}$' or p_manifest->>'kind'<>'preferences' or p_manifest->>'comparison'<>'identical-positions-v1' or jsonb_typeof(p_manifest->'questions') is distinct from 'array' or jsonb_array_length(p_manifest->'questions')<>10 or length(p_hypothesis) not between 20 and 2000 then raise exception 'Invalid candidate manifest';end if;
 if (select count(distinct x->>'id') from jsonb_array_elements(p_manifest->'questions') x)<>10 then raise exception 'Distinct question IDs required';end if;
 for q in select value from jsonb_array_elements(p_manifest->'questions') loop
  if coalesce(q->>'id','') !~ '^[a-z0-9-]{1,80}$' or length(coalesce(q->>'title','')) not between 5 and 160 or q ? 'answer' or jsonb_typeof(q->'options') is distinct from 'array' or jsonb_array_length(q->'options')<>2 then raise exception 'Invalid question';end if;
  if coalesce(q->>'image','') !~ '^/shopping/editions/[a-z0-9-]+/images/[a-z0-9-]+[.]webp$' then raise exception 'Edition-scoped reviewed asset required';end if;
  if not exists(select 1 from public.cq_versions v cross join lateral jsonb_array_elements(v.content->'questions') x where x->>'image'=q->>'image') then raise exception 'New imagery requires a reviewed asset registration before automated use';end if;
  if exists(select 1 from public.cq_versions v cross join lateral jsonb_array_elements(v.content->'questions') x where x->>'id'=q->>'id' and x<>q) then raise exception 'Changed question needs a new immutable question ID';end if;
  for o in select value from jsonb_array_elements(q->'options') loop
   if length(coalesce(o->>'label','')) not between 1 and 80 or length(coalesce(o->>'detail','')) not between 1 and 200 then raise exception 'Invalid option';end if;
  end loop;
 end loop;
 insert into public.cq_versions(version,slug,content) values(candidate_v,'shopping',p_manifest);
 insert into public.cq_fashion_experiments(control_version,candidate_version,hypothesis) values(current_v,candidate_v,p_hypothesis) returning id into eid;
 return eid;
end $$;
revoke all on function public.cq_register_candidate(jsonb,text) from public,anon,authenticated;

create or replace function public.cq_start_experiment(p_id bigint) returns void language plpgsql security definer set search_path='' as $$
declare e public.cq_fashion_experiments;c public.cq_fashion_release;
begin
 select * into c from public.cq_fashion_release where singleton for update;
 select * into e from public.cq_fashion_experiments where id=p_id for update;
 if e.id is null or e.status<>'draft' or e.control_version<>c.default_version or c.experiment_id is not null then raise exception 'Invalid experiment state';end if;
 if (public.cq_fashion_report(e.control_version)->>'settled_starts')::int<200 then raise exception 'Insufficient sample';end if;
 update public.cq_fashion_experiments set status='running',started_at=now() where id=p_id;
 update public.cq_fashion_release set experiment_id=p_id where singleton;
end $$;
revoke all on function public.cq_start_experiment(bigint) from public,anon,authenticated;

create or replace function public.cq_wilson(p_success numeric,p_n numeric,p_upper boolean)
returns numeric language sql immutable set search_path='' as $$
select case when p_n<=0 then null else ((p_success/p_n+3.8416/(2*p_n))+(case when p_upper then 1 else -1 end)*1.96*sqrt((p_success/p_n*(1-p_success/p_n)+3.8416/(4*p_n))/p_n))/(1+3.8416/p_n) end;
$$;
revoke all on function public.cq_wilson(numeric,numeric,boolean) from public,anon,authenticated;

create or replace function public.cq_evaluate_experiments() returns integer language plpgsql security definer set search_path='' as $$
declare e record;cn integer;tn integer;cs integer;ts integer;cshare integer;tshare integer;outcome text;changed integer=0;
begin
 for e in select * from public.cq_fashion_experiments where status='running' for update skip locked loop
 -- Fixed first 200 randomized starts per arm, each with a full day for outcomes.
 select count(*),count(*) filter(where completed),count(*) filter(where shared) into cn,cs,cshare from (select s.* from public.cq_fashion_sessions s join public.cq_attempts a on a.id=s.id where a.experiment_id=e.id and s.version=e.control_version order by s.started_at,s.id limit 200) x where started_at<now()-interval '1 day';
 select count(*),count(*) filter(where completed),count(*) filter(where shared) into tn,ts,tshare from (select s.* from public.cq_fashion_sessions s join public.cq_attempts a on a.id=s.id where a.experiment_id=e.id and s.version=e.candidate_version order by s.started_at,s.id limit 200) x where started_at<now()-interval '1 day';
 update public.cq_fashion_experiments set report=jsonb_build_object('control_starts',cn,'candidate_starts',tn,'control_completions',cs,'candidate_completions',ts,'control_sharers',cshare,'candidate_sharers',tshare,'decision','awaiting_200_mature_starts_per_arm') where id=e.id;
 if cn<200 or tn<200 then continue;end if;
 outcome=case when public.cq_wilson(ts,tn,false)>public.cq_wilson(cs,cn,true) and tshare>=cshare then 'promoted' when ts<cs then 'rolled_back' else 'inconclusive' end;
 update public.cq_fashion_experiments set status=outcome,ended_at=now(),report=report||jsonb_build_object('decision',outcome,'method','Fixed 200 starts/arm, 24h observation, non-overlapping 95% Wilson completion intervals and no fewer sharers; no profitability claim') where id=e.id;
 update public.cq_fashion_release set default_version=case when outcome='promoted' then e.candidate_version else e.control_version end,experiment_id=null where singleton and experiment_id=e.id;
 changed=changed+1;
 end loop;return changed;
end $$;
revoke all on function public.cq_evaluate_experiments() from public,anon,authenticated;

create or replace function public.cq_optimization_tick() returns jsonb language plpgsql security definer set search_path='' as $$
begin return public.cq_run_reviews()||jsonb_build_object('evaluated_experiments',public.cq_evaluate_experiments());end $$;
revoke all on function public.cq_optimization_tick() from public,anon,authenticated;
select cron.schedule('cq-fashion-review','*/5 * * * *','select public.cq_optimization_tick();');
commit;
select public.cq_optimization_tick();
select jobid,jobname,schedule,active from cron.job where jobname in('cq-fashion-review','cq-analytics-retention');
