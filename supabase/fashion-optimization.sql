-- Owner-applied instrumentation, immutable releases and aggregate review service.
begin;
alter table public.cq_events add column if not exists duration_ms integer;
create or replace function public.cq_record_events(p_attempt uuid,p_version text,p_referral uuid,p_source_ref uuid,p_attribution jsonb,p_events jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare e jsonb; v jsonb; a public.cq_attempts; n int; s int; q int; ans int; k text;
begin
 if p_attempt is null or p_referral is null or p_attempt=p_referral then raise exception 'Invalid identifiers'; end if;
 select content into v from public.cq_versions where version=p_version;
 if v is null then raise exception 'Unknown version'; end if;
 if p_attribution is null or jsonb_typeof(p_attribution)<>'object' or octet_length(p_attribution::text)>1500 then raise exception 'Invalid attribution'; end if;
 for k in select jsonb_object_keys(p_attribution) loop
   if k not in ('utm_source','utm_medium','utm_campaign','utm_content','utm_term') or jsonb_typeof(p_attribution->k)<>'string' or length(p_attribution->>k)>120 then raise exception 'Invalid campaign field'; end if;
 end loop;
 if p_events is null or jsonb_typeof(p_events)<>'array' or jsonb_array_length(p_events) not between 1 and 20 or octet_length(p_events::text)>12000 then raise exception 'Invalid batch'; end if;
 insert into public.cq_attempts(id,version,referral,source_ref,attribution) values(p_attempt,p_version,p_referral,p_source_ref,p_attribution) on conflict(id) do nothing;
 select * into a from public.cq_attempts where id=p_attempt for update;
 if a.version<>p_version or a.referral<>p_referral or a.created_at < now()-interval '1 day' then raise exception 'Attempt mismatch or expired'; end if;
 for e in select value from jsonb_array_elements(p_events) loop
   if jsonb_typeof(e)<>'object' or not(e ? 'seq') or not(e ? 'type') then raise exception 'Invalid event'; end if;
   n=(e->>'seq')::int;k=e->>'type';q=null;ans=null;s=null;
   if n not between 0 and 59 or k not in ('consent_granted','quiz_started','referred_arrival','question_shown','question_answered','quiz_completed','share_opened','share_completed','share_cancelled','link_copied','copy_fallback_shown','question_ready','image_failed','quiz_resumed','page_hidden') then raise exception 'Invalid event'; end if;
   if k in ('question_shown','question_answered','question_ready','image_failed','quiz_resumed','page_hidden') then
     q=(e->>'question')::int;
     if q is null or q not between 0 and 9 then raise exception 'Invalid question'; end if;
   end if;
   if k='question_answered' then
     ans=(e->>'answer')::int;
     if ans is null or ans not in (0,1) then raise exception 'Invalid answer'; end if;
   end if;
   if k='quiz_completed' then
     if jsonb_typeof(e->'answers') is distinct from 'array' or jsonb_array_length(e->'answers')<>10 then raise exception 'Invalid completion'; end if;
     s=0;
     for q in 0..9 loop
       ans=(e->'answers'->>q)::int;
       if ans is null or ans not in (0,1) then raise exception 'Invalid answer'; end if;
       if not exists(select 1 from public.cq_events where attempt=p_attempt and type='question_answered' and question=q and answer=ans) then raise exception 'Missing answer event'; end if;
       if ans=(v->'questions'->q->>'answer')::int then s=s+1; end if;
     end loop;
     if v->>'kind'='preferences' then s=null; end if;
     q=null;ans=null;
   end if;
   insert into public.cq_events(attempt,seq,type,question,answer,score,duration_ms) values(p_attempt,n,k,q,ans,s,case when k in ('question_ready','image_failed') then least(60000,greatest(0,(e->>'duration_ms')::int)) else null end) on conflict(attempt,seq) do nothing;
 end loop;
end $$;
revoke all on function public.cq_record_events(uuid,text,uuid,uuid,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.cq_record_events(uuid,text,uuid,uuid,jsonb,jsonb) to anon,authenticated;

-- This is the one-time manifest freeze for the existing fashion release: same
-- questions/options/order/images, now under permanent edition-scoped asset URLs.
update public.cq_versions set content=$manifest${
  "version": "fashion-v1",
  "kind": "preferences",
  "title": "How close is your style?",
  "questions": [
    {
      "id": "look-01",
      "title": "City plans. Which look?",
      "image": "/shopping/editions/fashion-v1/images/look-01.webp",
      "options": [
        {
          "label": "Sharp tailoring",
          "detail": "A charcoal suit with loafers"
        },
        {
          "label": "Dark florals",
          "detail": "A floral midi dress with burgundy boots"
        }
      ]
    },
    {
      "id": "look-02",
      "title": "Your knitwear mood?",
      "image": "/shopping/editions/fashion-v1/images/look-02.webp",
      "options": [
        {
          "label": "A shot of purple",
          "detail": "Purple knit and slim black trousers"
        },
        {
          "label": "Soft head-to-toe grey",
          "detail": "Grey knit, flowing trousers and trainers"
        }
      ]
    },
    {
      "id": "look-03",
      "title": "The layer you reach for?",
      "image": "/shopping/editions/fashion-v1/images/look-03.webp",
      "options": [
        {
          "label": "Cropped suede",
          "detail": "Chestnut suede jacket with jeans"
        },
        {
          "label": "The long coat",
          "detail": "Camel wool coat with jeans"
        }
      ]
    },
    {
      "id": "look-04",
      "title": "Dinner at your favourite spot.",
      "image": "/shopping/editions/fashion-v1/images/look-04.webp",
      "options": [
        {
          "label": "Satin & soft knit",
          "detail": "Burgundy satin skirt with grey knit"
        },
        {
          "label": "Relaxed tailoring",
          "detail": "Burgundy trousers with grey knit"
        }
      ]
    },
    {
      "id": "look-05",
      "title": "Let the sleeves do the talking?",
      "image": "/shopping/editions/fashion-v1/images/look-05.webp",
      "options": [
        {
          "label": "A little drama",
          "detail": "Ivory balloon-sleeve blouse with black trousers"
        },
        {
          "label": "Keep it clean",
          "detail": "Ivory fitted knit with black trousers"
        }
      ]
    },
    {
      "id": "look-06",
      "title": "An evening invitation.",
      "image": "/shopping/editions/fashion-v1/images/look-06.webp",
      "options": [
        {
          "label": "Velvet dress",
          "detail": "Black velvet midi dress and heels"
        },
        {
          "label": "Evening tuxedo",
          "detail": "Black tuxedo, silk top and heels"
        }
      ]
    },
    {
      "id": "look-07",
      "title": "Make your denim interesting.",
      "image": "/shopping/editions/fashion-v1/images/look-07.webp",
      "options": [
        {
          "label": "Utility layers",
          "detail": "Olive utility jacket with jeans and trainers"
        },
        {
          "label": "Rich brocade",
          "detail": "Burgundy brocade jacket with jeans and flats"
        }
      ]
    },
    {
      "id": "look-08",
      "title": "One final styling touch.",
      "image": "/shopping/editions/fashion-v1/images/look-08.webp",
      "options": [
        {
          "label": "Tonal scarf",
          "detail": "Brown blazer and tonal chocolate scarf"
        },
        {
          "label": "Colour clash",
          "detail": "Brown blazer and purple-red scarf"
        }
      ]
    },
    {
      "id": "look-09",
      "title": "Choose your silhouette.",
      "image": "/shopping/editions/fashion-v1/images/look-09.webp",
      "options": [
        {
          "label": "Asymmetric hem",
          "detail": "Cream cardigan with asymmetric brown skirt"
        },
        {
          "label": "A straight line",
          "detail": "Cream cardigan with straight brown skirt"
        }
      ]
    },
    {
      "id": "look-10",
      "title": "Same outfit. Different energy.",
      "image": "/shopping/editions/fashion-v1/images/look-10.webp",
      "options": [
        {
          "label": "Clean trainers",
          "detail": "Navy jacket and grey trousers with white trainers"
        },
        {
          "label": "A little sparkle",
          "detail": "Navy jacket and grey trousers with silver trainers"
        }
      ]
    }
  ],
  "comparison": "identical-positions-v1",
  "assetVersion": "fashion-v1"
}$manifest$::jsonb where version='fashion-v1';
create or replace function public.cq_protect_version() returns trigger language plpgsql set search_path='' as $$begin
 if new.version is distinct from old.version or new.content is distinct from old.content or new.slug is distinct from old.slug then raise exception 'Quiz editions are immutable; create a new version';end if;return new;end $$;
create trigger cq_version_immutable before update on public.cq_versions for each row execute function public.cq_protect_version();
create table public.cq_fashion_release (
 singleton boolean primary key default true check(singleton),
 default_version text not null references public.cq_versions(version),
 experiment_id bigint
);
insert into public.cq_fashion_release(singleton,default_version) values(true,'fashion-v1');
create table public.cq_optimization_reviews (
 id bigint generated always as identity primary key,
 version text not null references public.cq_versions(version), batch integer not null,
 state text not null default 'awaiting_session_settlement',
 queued_at timestamptz not null default now(), analyzed_at timestamptz,
 report jsonb, unique(version,batch)
);
create table public.cq_review_members(review_id bigint references public.cq_optimization_reviews(id),attempt uuid references public.cq_attempts(id) on delete cascade,primary key(review_id,attempt));
create table public.cq_fashion_experiments (
 id bigint generated always as identity primary key,
 control_version text not null references public.cq_versions(version),
 candidate_version text not null references public.cq_versions(version),
 hypothesis text not null, status text not null default 'draft' check(status in ('draft','running','promoted','rolled_back','inconclusive')),
 started_at timestamptz, ended_at timestamptz, report jsonb,
 check(control_version<>candidate_version)
);
alter table public.cq_fashion_release enable row level security;
alter table public.cq_optimization_reviews enable row level security;
alter table public.cq_review_members enable row level security;
alter table public.cq_fashion_experiments enable row level security;
revoke all on public.cq_fashion_release,public.cq_optimization_reviews,public.cq_review_members,public.cq_fashion_experiments from public,anon,authenticated;

create or replace function public.cq_resolve_fashion(p_requested text,p_bucket integer)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v text; c public.cq_fashion_release; ex public.cq_fashion_experiments; answer jsonb;
begin
 if p_bucket is null or p_bucket not between 0 and 99 then raise exception 'Invalid allocation';end if;
 if p_requested is not null then v=p_requested;else
 select * into c from public.cq_fashion_release where singleton;
 v=c.default_version;
 if c.experiment_id is not null then
 select * into ex from public.cq_fashion_experiments where id=c.experiment_id and status='running';
 if found then v=case when p_bucket<50 then ex.control_version else ex.candidate_version end;end if;
 end if;
 end if;
 select content into answer from public.cq_versions where version=v and content->>'kind'='preferences';
 if answer is null then raise exception 'Edition unavailable';end if;return answer;
end $$;
revoke all on function public.cq_resolve_fashion(text,integer) from public,anon,authenticated;
grant execute on function public.cq_resolve_fashion(text,integer) to anon,authenticated;

-- Anonymous event APIs remain bounded; all reporting views are owner-only.
create or replace view public.cq_fashion_sessions as
select a.id,a.version,a.referral,a.source_ref,a.attribution,
 coalesce(a.attribution->>'utm_source','direct') as source,
 coalesce(a.attribution->>'utm_campaign','none') as campaign,
 min(e.created_at) filter(where e.type='quiz_started') as started_at,
 max(e.created_at) as last_at,
 bool_or(e.type='quiz_completed') as completed,
 bool_or(e.type in ('share_completed','link_copied')) as shared,
 bool_or(e.type='quiz_resumed') as resumed,
 count(distinct e.question) filter(where e.type='question_shown') as observed_questions,
 case when bool_or(e.type='quiz_completed') then 'completed'
 when max(e.created_at)>now()-interval '30 minutes' then 'active' else 'observed_stop' end as state
from public.cq_attempts a join public.cq_versions v on v.version=a.version
join public.cq_events e on e.attempt=a.id
where v.slug='shopping' and v.content->>'kind'='preferences'
 and coalesce(a.attribution->>'utm_source','') not in ('launch_validation','automated_qa')
group by a.id having bool_or(e.type='quiz_started');
revoke all on public.cq_fashion_sessions from public,anon,authenticated;

create or replace view public.cq_question_observations as
select s.*, q.question, v.content->'questions'->q.question->>'id' as question_id,
 bool_or(e.type='question_shown') as exposed,
 bool_or(e.type='question_answered') as answered,
 max(e.answer) filter(where e.type='question_answered') as answer,
 bool_or(e.type='image_failed') as image_failed,
 max(e.duration_ms) filter(where e.type='question_ready') as load_ms,
 exists(select 1 from public.cq_events n where n.attempt=s.id and n.type='question_shown' and n.question=q.question+1) as advanced
from public.cq_fashion_sessions s join public.cq_versions v on v.version=s.version
cross join generate_series(0,9) q(question)
left join public.cq_events e on e.attempt=s.id and e.question=q.question
group by s.id,s.version,s.referral,s.source_ref,s.attribution,s.source,s.campaign,s.started_at,s.last_at,s.completed,s.shared,s.resumed,s.observed_questions,s.state,q.question,v.content;
revoke all on public.cq_question_observations from public,anon,authenticated;

create or replace function public.cq_fashion_report(p_version text,p_cutoff timestamptz default now())
returns jsonb language sql stable security definer set search_path='' as $$
with sessions as(select *,row_number() over(order by started_at desc,id) as recency from public.cq_fashion_sessions where version=p_version and started_at<=p_cutoff and state<>'active'),
obs as(select o.*,s.recency from public.cq_question_observations o join sessions s on s.id=o.id),
windows as(select 'cumulative' as window_name,* from obs union all select 'recent_50',* from obs where recency<=50 union all select 'earlier',* from obs where recency>50),
questions as(select window_name,question,question_id,count(*) filter(where exposed) as exposures,
 count(*) filter(where exposed and answered) as answers,
 count(*) filter(where exposed and not answered) as observed_stops,
 count(*) filter(where exposed and (advanced or (question=9 and completed))) as continuations,
 count(*) filter(where exposed and completed) as completions,
 count(*) filter(where exposed and shared) as sharers,
 count(*) filter(where exposed and answer=0) as a_votes,
 count(*) filter(where exposed and answer=1) as b_votes,
 count(*) filter(where exposed and image_failed) as image_failures,
 round(avg(load_ms) filter(where exposed)) as mean_image_ready_ms,
 count(*) filter(where not exposed and answered) as missing_exposure_events
 from windows group by window_name,question,question_id),
cohorts as(select source,campaign,count(*) as settled_starts,count(*) filter(where completed) as completions,count(*) filter(where shared) as sharers from sessions group by source,campaign)
select jsonb_build_object(
 'version',p_version,'as_of',now(),'settlement_minutes',30,
 'settled_starts',(select count(*) from sessions),
 'active_starts',(select count(*) from public.cq_fashion_sessions where version=p_version and state='active' and started_at<=p_cutoff),
 'completions',(select count(*) from sessions where completed),
 'sharers',(select count(*) from sessions where shared),
 'resumed_sessions',(select count(*) from sessions where resumed),
 'referred_starts',(select count(*) from public.cq_fashion_sessions child where child.source_ref in(select referral from sessions)),
 'referred_completions',(select count(*) from public.cq_fashion_sessions child where child.completed and child.source_ref in(select referral from sessions)),
 'questions',coalesce((select jsonb_agg(to_jsonb(q) order by window_name,question) from questions q),'[]'),
 'cohorts',coalesce((select jsonb_agg(to_jsonb(c)) from cohorts c),'[]'),
 'limitations','Opted-in observed sessions only; stopped observation can mean exit, consent withdrawal, network loss or missing events. No skip control exists. Active sessions excluded. Question, position, ad adjacency, load and acquisition effects are not causal conclusions. Recent versus earlier windows may have cohort drift. Share action is not a referred play. No revenue/paid acquisition data linked.',
 'decision',case when (select count(*) from sessions)<200 then 'insufficient_sample_no_change' else 'candidate_review_required' end
);
$$;
revoke all on function public.cq_fashion_report(text,timestamptz) from public,anon,authenticated;

create or replace function public.cq_queue_reviews() returns void language plpgsql security definer set search_path='' as $$
declare r record; rid bigint;
begin
 perform pg_advisory_xact_lock(70926101);
 for r in select version,(count(*)/10)::integer batches from public.cq_fashion_sessions s where not exists(select 1 from public.cq_review_members m where m.attempt=s.id) group by version loop
  for b in 1..r.batches loop
   insert into public.cq_optimization_reviews(version,batch) select r.version,coalesce(max(batch),0)+1 from public.cq_optimization_reviews where version=r.version returning id into rid;
   insert into public.cq_review_members(review_id,attempt) select rid,s.id from public.cq_fashion_sessions s where s.version=r.version and not exists(select 1 from public.cq_review_members m where m.attempt=s.id) order by started_at,id limit 10;
  end loop;
 end loop;
end $$;
revoke all on function public.cq_queue_reviews() from public,anon,authenticated;

create or replace function public.cq_review_on_start() returns trigger language plpgsql security definer set search_path='' as $$begin
 if new.type='quiz_started' then perform public.cq_queue_reviews();end if;return new;end $$;
create trigger cq_fashion_review_on_start after insert on public.cq_events for each row execute function public.cq_review_on_start();

create or replace function public.cq_run_reviews() returns jsonb language plpgsql security definer set search_path='' as $$
declare r record; payload jsonb; done_count integer=0;
begin
 perform public.cq_queue_reviews();
 for r in select * from public.cq_optimization_reviews where analyzed_at is null or queued_at>now()-interval '1 day' order by id for update skip locked loop
  if exists(select 1 from public.cq_review_members m join public.cq_fashion_sessions s on s.id=m.attempt where m.review_id=r.id and s.state='active') then continue;end if;
  payload=public.cq_fashion_report(r.version,(select max(s.started_at) from public.cq_review_members m join public.cq_fashion_sessions s on s.id=m.attempt where m.review_id=r.id));
  payload=payload||jsonb_build_object('batch_questions',(select jsonb_agg(to_jsonb(q)) from (
    select o.question_id,o.question,count(*) filter(where exposed) exposures,count(*) filter(where exposed and answered) answers,count(*) filter(where exposed and completed) completions,count(*) filter(where exposed and shared) sharers,count(*) filter(where exposed and answer=0) a_votes,count(*) filter(where exposed and answer=1) b_votes
    from public.cq_question_observations o join public.cq_review_members m on m.attempt=o.id where m.review_id=r.id group by o.question_id,o.question
  ) q));
  update public.cq_optimization_reviews set report=payload,analyzed_at=now(),state=payload->>'decision' where id=r.id;
  done_count=done_count+1;
 end loop;
 return jsonb_build_object('reviewed_batches',done_count,'minimum_candidate_sample',200,'automatic_content_generation','not_configured');
end $$;
revoke all on function public.cq_run_reviews() from public,anon,authenticated;
create or replace view public.cq_question_history as
select r.version,q->>'question_id' as question_id,(q->>'question')::integer as position,
 sum((q->>'exposures')::bigint) exposures,sum((q->>'answers')::bigint) answers,
 sum((q->>'completions')::bigint) completions,sum((q->>'sharers')::bigint) sharers,
 sum((q->>'a_votes')::bigint) a_votes,sum((q->>'b_votes')::bigint) b_votes,
 count(*) reviewed_batches,max(r.analyzed_at) updated_at
from public.cq_optimization_reviews r cross join lateral jsonb_array_elements(r.report->'batch_questions') q
where r.analyzed_at is not null group by r.version,q->>'question_id',(q->>'question')::integer;
revoke all on public.cq_question_history from public,anon,authenticated;
commit;
select public.cq_fashion_report('fashion-v1');
