begin;
insert into public.cq_versions(version,slug,content) select 'fashion-exp-control','shopping',jsonb_set(content,'{version}','"fashion-exp-control"') from public.cq_versions where version='fashion-v1';
insert into public.cq_versions(version,slug,content) select 'fashion-exp-candidate','shopping',jsonb_set(content,'{version}','"fashion-exp-candidate"') from public.cq_versions where version='fashion-v1';
do $$
declare eid bigint; aid uuid; v text; original jsonb;
begin
 original=public.cq_resolve_fashion('fashion-v1',0)-'allocation';
 insert into public.cq_fashion_experiments(control_version,candidate_version,hypothesis,status,started_at) values('fashion-exp-control','fashion-exp-candidate','Rollback-only evaluation fixture','running',now()-interval '3 days') returning id into eid;
 update public.cq_fashion_release set default_version='fashion-exp-control',experiment_id=eid where singleton;
 if public.cq_resolve_fashion(null,0)->>'version'<>'fashion-exp-control' or public.cq_resolve_fashion(null,99)->>'version'<>'fashion-exp-candidate' then raise exception 'Allocation failure';end if;
 if public.cq_evaluate_experiments()<>0 then raise exception 'Premature promotion';end if;
 for arm in 0..1 loop
  v=case when arm=0 then 'fashion-exp-control' else 'fashion-exp-candidate' end;
  for i in 1..200 loop
   aid=gen_random_uuid();
   insert into public.cq_attempts(id,version,referral,experiment_id,created_at) values(aid,v,gen_random_uuid(),eid,now()-interval '2 days');
   insert into public.cq_events(attempt,seq,type,created_at) values(aid,0,'quiz_started',now()-interval '2 days');
   if arm=1 or i<=100 then insert into public.cq_events(attempt,seq,type,created_at) values(aid,1,'quiz_completed',now()-interval '2 days'+interval '1 minute');end if;
   if i<=20 then insert into public.cq_events(attempt,seq,type,created_at) values(aid,2,'link_copied',now()-interval '2 days'+interval '2 minutes');end if;
  end loop;
 end loop;
 if public.cq_evaluate_experiments()<>1 then raise exception 'Expected one decision';end if;
 if (select status from public.cq_fashion_experiments where id=eid)<>'promoted' or public.cq_resolve_fashion(null,0)->>'version'<>'fashion-exp-candidate' then raise exception 'Sufficient winning candidate not promoted';end if;
 if public.cq_resolve_fashion('fashion-v1',99)-'allocation'<>original then raise exception 'Original challenge mutated after promotion';end if;
end $$;
select 'PASS: 50/50 assignment, insufficient-sample hold, fixed 200 mature starts per arm, guarded promotion, old challenge preserved; all fixtures rolled back' as validation;
rollback;
