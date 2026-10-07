-- Owner-only report. Execute in Supabase SQL Editor; no public admin endpoint.
-- Live schema deliberately has no anon/authenticated access to these views.
select version,source,campaign,count(*) starts,
 count(*) filter(where state='active') active,
 count(*) filter(where state='observed_stop') observed_stops,
 count(*) filter(where completed) completions,
 count(*) filter(where shared) sharers,
 count(*) filter(where resumed) resumed
from public.cq_fashion_sessions group by version,source,campaign order by version,starts desc;

with report as(select public.cq_fashion_report(default_version) data from public.cq_fashion_release),
q as(select x.* from report cross join lateral jsonb_to_recordset(data->'questions') x(window_name text,question integer,question_id text,exposures integer,answers integer,observed_stops integer,continuations integer,completions integer,sharers integer,a_votes integer,b_votes integer,image_failures integer,mean_image_ready_ms numeric,missing_exposure_events integer))
select question+1 as position,question_id,window_name,exposures,answers,observed_stops,
 round(100.0*observed_stops/nullif(exposures,0),1) observed_stop_pct,
 round(100.0*continuations/nullif(exposures,0),1) continuation_pct,
 completions,sharers,a_votes,b_votes,image_failures,mean_image_ready_ms,missing_exposure_events
from q order by question,window_name;

with report as(select public.cq_fashion_report(default_version) data from public.cq_fashion_release),
q as(select x.* from report cross join lateral jsonb_to_recordset(data->'questions') x(window_name text,question_id text,exposures integer,answers integer))
select r.question_id,r.exposures recent_exposures,p.exposures previous_exposures,
 round(100.0*r.answers/nullif(r.exposures,0),1) recent_answer_pct,
 round(100.0*p.answers/nullif(p.exposures,0),1) previous_answer_pct,
 case when r.exposures<30 or coalesce(p.exposures,0)<50 then 'insufficient recent/prior sample'
 when 1.0*p.answers/p.exposures-1.0*r.answers/r.exposures>=0.15 then 'decline to investigate; check source mix, position, ads and load'
 else 'no 15-point decline signal' end diagnosis
from q r left join q p on p.question_id=r.question_id and p.window_name='earlier' where r.window_name='recent_50';

-- All historical analyzed batches survive 90-day raw-data cleanup.
-- Batches awaiting ten starts or settlement are absent from this historical view.
select *,round(100.0*answers/nullif(exposures,0),1) historical_answer_pct from public.cq_question_history order by exposures desc;
select id,version,batch,state,queued_at,analyzed_at from public.cq_optimization_reviews order by id desc limit 20;
select id,control_version,candidate_version,status,report from public.cq_fashion_experiments order by id desc;
select j.jobname,d.status,d.start_time,d.end_time,d.return_message from cron.job_run_details d join cron.job j using(jobid) where j.jobname in('cq-fashion-review','cq-analytics-retention') order by d.start_time desc limit 10;
