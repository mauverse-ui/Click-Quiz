-- Transaction-only synthetic fixtures. Nothing is committed or added to public counts.
begin;
insert into public.cq_versions(version,slug,content) select 'fashion-validation','validation',content from public.cq_versions where version='fashion-v1';
do $$
declare aid uuid; voter uuid; first_a uuid; first_v uuid; ev jsonb; result jsonb; begin
 for n in 1..20 loop
  aid=gen_random_uuid();voter=gen_random_uuid();
  if n=1 then first_a=aid;first_v=voter;end if;
  select jsonb_agg(jsonb_build_object('seq',q,'type','question_answered','question',q,'answer',case when n<=12 then 0 else 1 end)) into ev from generate_series(0,9) q;
  ev=ev||jsonb_build_array(jsonb_build_object('seq',10,'type','quiz_completed','answers',case when n<=12 then '[0,0,0,0,0,0,0,0,0,0]'::jsonb else '[1,1,1,1,1,1,1,1,1,1]'::jsonb end));
  perform public.cq_record_events(aid,'fashion-validation',gen_random_uuid(),null,'{}',ev);
  perform public.cq_fashion_vote(voter,aid);
  perform public.cq_fashion_vote(voter,aid);
 end loop;
 perform public.cq_fashion_vote(gen_random_uuid(),first_a);
 perform public.cq_fashion_vote(first_v,aid);
 result=public.cq_fashion_crowd('fashion-validation');
 if (result->>'n')::int<>20 or result->'a'<>'[12,12,12,12,12,12,12,12,12,12]'::jsonb then raise exception 'Deduplication/count failure: %',result;end if;
 if exists(select 1 from public.cq_events e join public.cq_attempts a on a.id=e.attempt where a.version='fashion-validation' and e.type='quiz_completed' and e.score is not null) then raise exception 'Preference quiz has score';end if;
 begin
  perform public.cq_fashion_vote(gen_random_uuid(),gen_random_uuid());
  raise exception 'Incomplete accepted';
 exception when raise_exception then if SQLERRM='Incomplete accepted' then raise;end if;
 end;
end $$;
select 'PASS: 20 ballots, 60% A splits, repeated voter/attempt deduped, preference score null, incomplete rejected; rolling back fixtures' as validation;
rollback;
