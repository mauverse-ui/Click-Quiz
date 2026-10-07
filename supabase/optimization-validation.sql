-- All fixtures and release changes are rolled back; public results stay untouched.
begin;
insert into public.cq_versions(version,slug,content) select 'fashion-report-test','shopping',jsonb_set(content,'{version}','"fashion-report-test"') from public.cq_versions where version='fashion-v1';
do $$
declare a uuid; r jsonb;q jsonb;n integer; original jsonb;changed jsonb;
begin
 for i in 1..10 loop
 a=gen_random_uuid();
 perform public.cq_record_events(a,'fashion-report-test',gen_random_uuid(),null,'{}','[{"seq":0,"type":"quiz_started"},{"seq":1,"type":"question_shown","question":0},{"seq":2,"type":"question_shown","question":0}]');
 if i<=5 then perform public.cq_record_events(a,'fashion-report-test',(select referral from public.cq_attempts where id=a),null,'{}','[{"seq":3,"type":"question_answered","question":0,"answer":0}]');end if;
 if i=9 and exists(select 1 from public.cq_optimization_reviews where version='fashion-report-test') then raise exception 'Review before ten starts';end if;
 end loop;
 select count(*) into n from public.cq_optimization_reviews where version='fashion-report-test';if n<>1 then raise exception 'Expected exactly one batch';end if;
 perform public.cq_run_reviews();
 if exists(select 1 from public.cq_optimization_reviews where version='fashion-report-test' and analyzed_at is not null) then raise exception 'Active sessions counted as abandoned';end if;
 update public.cq_events set created_at=now()-interval '40 minutes' where attempt in(select id from public.cq_attempts where version='fashion-report-test');
 perform public.cq_run_reviews();perform public.cq_run_reviews();
 r=public.cq_fashion_report('fashion-report-test');
 select x into q from jsonb_array_elements(r->'questions') x where x->>'window_name'='cumulative' and x->>'question'='0';
 if (q->>'exposures')::int<>10 or (q->>'answers')::int<>5 or (q->>'observed_stops')::int<>5 then raise exception 'Deduped exposure funnel failed: %',q;end if;
 if r->>'decision'<>'insufficient_sample_no_change' then raise exception 'Ten starts published a change';end if;
 if (select exposures from public.cq_question_history where version='fashion-report-test' and position=0)<>10 then raise exception 'Historical snapshot duplicated';end if;
 begin update public.cq_versions set content=content||'{"changed":true}' where version='fashion-v1';raise exception 'Mutation accepted';exception when raise_exception then if SQLERRM='Mutation accepted' then raise;end if;end;
 original=public.cq_resolve_fashion('fashion-v1',0)-'allocation';
 changed=jsonb_set(original,'{version}','"fashion-default-test"');
 select jsonb_set(changed,'{questions}',jsonb_agg(value order by ordinality desc)) into changed from jsonb_array_elements(original->'questions') with ordinality;
 insert into public.cq_versions(version,slug,content) values('fashion-default-test','shopping',changed);
 update public.cq_fashion_release set default_version='fashion-default-test' where singleton;
 if public.cq_resolve_fashion(null,0)->>'version'<>'fashion-default-test' then raise exception 'Default routing failed';end if;
 if public.cq_resolve_fashion('fashion-v1',99)-'allocation'<>original then raise exception 'Old friend edition changed';end if;
 begin perform public.cq_register_candidate(jsonb_set(original,'{version}','"fashion-too-soon"'),'Testing insufficient sample must not launch candidate');raise exception 'Candidate accepted too early';exception when raise_exception then if SQLERRM='Candidate accepted too early' then raise;end if;end;
end $$;
select 'PASS: ten-start trigger; active sessions held; exposure deduplication; 50% observed stop; historical deduplication; insufficient-sample no-change; immutable old version after new default' as validation;
rollback;
