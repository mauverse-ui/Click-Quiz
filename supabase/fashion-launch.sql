-- Additive fashion release; old shopping content and share links remain valid.
begin;
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
   if n not between 0 and 59 or k not in ('consent_granted','quiz_started','referred_arrival','question_shown','question_answered','quiz_completed','share_opened','share_completed','share_cancelled','link_copied','copy_fallback_shown') then raise exception 'Invalid event'; end if;
   if k in ('question_shown','question_answered') then
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
   insert into public.cq_events(attempt,seq,type,question,answer,score) values(p_attempt,n,k,q,ans,s) on conflict(attempt,seq) do nothing;
 end loop;
end $$;
revoke all on function public.cq_record_events(uuid,text,uuid,uuid,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.cq_record_events(uuid,text,uuid,uuid,jsonb,jsonb) to anon,authenticated;
create table if not exists public.cq_fashion_votes (
 version text not null references public.cq_versions(version),
 voter uuid not null, answers jsonb not null, created_at timestamptz not null default now(),
 primary key(version,voter), check(jsonb_typeof(answers)='array' and jsonb_array_length(answers)=10)
);
alter table public.cq_fashion_votes add column if not exists attempt uuid references public.cq_attempts(id) on delete cascade;
create unique index if not exists cq_fashion_vote_attempt on public.cq_fashion_votes(attempt);
alter table public.cq_fashion_votes enable row level security;
revoke all on public.cq_fashion_votes from anon,authenticated;
create or replace function public.cq_fashion_vote(p_voter uuid,p_attempt uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v text; picks jsonb;
begin
 if p_voter is null then raise exception 'Missing voter'; end if;
 select a.version into v from public.cq_attempts a join public.cq_versions q on q.version=a.version where a.id=p_attempt and q.content->>'kind'='preferences';
 if v is null or not exists(select 1 from public.cq_events where attempt=p_attempt and type='quiz_completed') then raise exception 'Complete attempt required'; end if;
 select jsonb_agg(answer order by question) into picks from (select distinct on(question) question,answer from public.cq_events where attempt=p_attempt and type='question_answered' order by question,seq) x;
 if jsonb_array_length(picks)<>10 then raise exception 'Ten choices required'; end if;
 insert into public.cq_fashion_votes(version,voter,answers,attempt) values(v,p_voter,picks,p_attempt) on conflict do nothing;
end $$;
revoke all on function public.cq_fashion_vote(uuid,uuid) from public,anon,authenticated;
grant execute on function public.cq_fashion_vote(uuid,uuid) to anon,authenticated;
create or replace function public.cq_fashion_crowd(p_version text)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare n bigint; counts jsonb;
begin
 select count(*) into n from public.cq_fashion_votes where version=p_version;
 if n<20 then return jsonb_build_object('n',n,'a','[]'::jsonb); end if;
 select jsonb_agg(c order by i) into counts from (select i,(select count(*) from public.cq_fashion_votes where version=p_version and (answers->>i)::int=0) c from generate_series(0,9) i) x;
 return jsonb_build_object('n',n,'a',counts);
end $$;
revoke all on function public.cq_fashion_crowd(text) from public,anon,authenticated;
grant execute on function public.cq_fashion_crowd(text) to anon,authenticated;
insert into public.cq_versions(version,slug,content) values('fashion-v1','shopping',$quiz${
  "version": "fashion-v1",
  "kind": "preferences",
  "title": "How close is your style?",
  "questions": [
    {
      "id": "look-01",
      "title": "City plans. Which look?",
      "image": "/shopping/images/look-01.webp",
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
      "image": "/shopping/images/look-02.webp",
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
      "image": "/shopping/images/look-03.webp",
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
      "image": "/shopping/images/look-04.webp",
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
      "image": "/shopping/images/look-05.webp",
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
      "image": "/shopping/images/look-06.webp",
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
      "image": "/shopping/images/look-07.webp",
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
      "image": "/shopping/images/look-08.webp",
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
      "image": "/shopping/images/look-09.webp",
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
      "image": "/shopping/images/look-10.webp",
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
  ]
}$quiz$::jsonb) on conflict(version) do nothing;
commit;
select public.cq_fashion_crowd('fashion-v1') as crowd;
