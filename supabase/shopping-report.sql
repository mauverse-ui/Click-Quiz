-- Run as database owner in Supabase SQL Editor; export its result as CSV.
-- Consent-based analytics are a sample, not all visitors. Anonymous public events
-- are not fraud-proof and must not serve as billing evidence.
with events as (
 select attempt, bool_or(type='quiz_started') as started,
 bool_or(type='quiz_completed') as completed, max(score) as score,
 bool_or(type in ('share_completed','link_copied')) as shared
 from public.cq_events group by attempt
)
select date_trunc('day',a.created_at) as day,a.version,
 a.attribution->>'utm_source' as source,a.attribution->>'utm_campaign' as campaign,
 case when a.source_ref is null then 'initial' else 'referred' end as visit_type,
 count(*) as consented_attempts,count(*) filter(where e.started) as starts,
 count(*) filter(where e.completed) as completions,round(avg(e.score),2) as average_score,
 count(*) filter(where e.shared) as share_actions,
 count(*) filter(where a.source_ref is not null and exists(select 1 from public.cq_attempts parent where parent.referral=a.source_ref)) as matched_referred_arrivals
from public.cq_attempts a left join events e on e.attempt=a.id
group by 1,2,3,4,5 order by 1 desc;
-- Retention maintenance, run as owner at least weekly until a scheduled job exists:
-- delete from public.cq_attempts where created_at < now() - interval '90 days';
-- Do not divide ad-zone revenue into invented exact individual visitor earnings.
-- Compare initial-session aggregate revenue with matched spend by network reporting
-- dimensions; record referred sessions separately. No profitability is established.
