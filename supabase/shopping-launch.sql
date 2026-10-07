-- Additive migration: does not alter legacy quiz tables.
begin;
create table if not exists public.cq_versions (
 version text primary key, slug text not null, content jsonb not null,
 created_at timestamptz not null default now()
);
create table if not exists public.cq_attempts (
 id uuid primary key, version text not null references public.cq_versions(version),
 referral uuid not null unique, source_ref uuid, attribution jsonb not null default '{}',
 created_at timestamptz not null default now()
);
create table if not exists public.cq_events (
 attempt uuid not null references public.cq_attempts(id) on delete cascade,
 seq smallint not null check(seq between 0 and 59), type text not null,
 question smallint, answer smallint, score smallint,
 created_at timestamptz not null default now(), primary key(attempt,seq)
);
create index if not exists cq_events_created on public.cq_events(created_at);
create index if not exists cq_attempts_source on public.cq_attempts(source_ref);
alter table public.cq_versions enable row level security;
alter table public.cq_attempts enable row level security;
alter table public.cq_events enable row level security;
revoke all on public.cq_versions,public.cq_attempts,public.cq_events from anon,authenticated;
grant select on public.cq_versions to anon,authenticated;
drop policy if exists cq_read_versions on public.cq_versions;
create policy cq_read_versions on public.cq_versions for select to anon,authenticated using(true);
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
     q=null;ans=null;
   end if;
   insert into public.cq_events(attempt,seq,type,question,answer,score) values(p_attempt,n,k,q,ans,s) on conflict(attempt,seq) do nothing;
 end loop;
end $$;
revoke all on function public.cq_record_events(uuid,text,uuid,uuid,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.cq_record_events(uuid,text,uuid,uuid,jsonb,jsonb) to anon,authenticated;
insert into public.cq_versions(version,slug,content) values ('shopping-v1','shopping', $quiz${
  "version": "shopping-v1",
  "title": "How sharp are your shopping instincts?",
  "questions": [
    {
      "id": "unit-price",
      "title": "The bigger bag wins… right?",
      "prompt": "Which bag costs less per 100 g?",
      "icon": "🥣",
      "options": [
        {
          "label": "Pocket oats",
          "detail": "400 g",
          "badge": "€1.80"
        },
        {
          "label": "Family oats",
          "detail": "750 g",
          "badge": "€3.75"
        }
      ],
      "answer": 0,
      "explanation": "Pocket oats cost €0.45 per 100 g. Family oats cost €0.50 per 100 g. Bigger isn’t always cheaper."
    },
    {
      "id": "delivery",
      "title": "A sneaky checkout twist",
      "prompt": "Same mug, same delivery date. Which order costs less in total?",
      "icon": "☕",
      "options": [
        {
          "label": "Mug Market",
          "detail": "€8 + €4 delivery",
          "badge": "€12 total"
        },
        {
          "label": "Cup Corner",
          "detail": "€11 + free delivery",
          "badge": "€11 total"
        }
      ],
      "answer": 1,
      "explanation": "Cup Corner totals €11. Mug Market totals €12 once delivery is included."
    },
    {
      "id": "budget",
      "title": "Build your picnic",
      "prompt": "You have €10. Which basket leaves at least €1 for the bus?",
      "icon": "🧺",
      "options": [
        {
          "label": "Basket A",
          "detail": "Wrap €4 · juice €2 · fruit €3",
          "badge": "3 items"
        },
        {
          "label": "Basket B",
          "detail": "Wrap €4 · juice €2 · cookies €3.50",
          "badge": "3 items"
        }
      ],
      "answer": 0,
      "explanation": "Basket A costs €9 and leaves €1. Basket B costs €9.50 and leaves only €0.50."
    },
    {
      "id": "bundle",
      "title": "Three pairs. One decision.",
      "prompt": "You need exactly 3 identical pairs of socks. Which offer costs less?",
      "icon": "🧦",
      "options": [
        {
          "label": "Single pairs",
          "detail": "€4 each · buy 2, get 1 free",
          "badge": "3 pairs"
        },
        {
          "label": "Ready-made pack",
          "detail": "3 pairs for €9",
          "badge": "3 pairs"
        }
      ],
      "answer": 0,
      "explanation": "Buy 2, get 1 free costs 2 × €4 = €8 for three pairs. The pack costs €9."
    },
    {
      "id": "discount",
      "title": "Big sticker, small saving?",
      "prompt": "These are identical lamps. Which sale price is lower?",
      "icon": "💡",
      "options": [
        {
          "label": "Shop A",
          "detail": "Was €40 · now 25% off",
          "badge": "25% OFF"
        },
        {
          "label": "Shop B",
          "detail": "Was €35 · now €7 off",
          "badge": "€7 OFF"
        }
      ],
      "answer": 1,
      "explanation": "Shop A: €40 − €10 = €30. Shop B: €35 − €7 = €28. Compare the final price, not the sticker."
    },
    {
      "id": "quantity",
      "title": "The party needs 12",
      "prompt": "You need at least 12 paper cups. Which purchase costs less?",
      "icon": "🥤",
      "options": [
        {
          "label": "Two small packs",
          "detail": "6 cups per pack · €2 each",
          "badge": "12 cups"
        },
        {
          "label": "One large pack",
          "detail": "15 cups · €4.50",
          "badge": "15 cups"
        }
      ],
      "answer": 0,
      "explanation": "Two small packs provide all 12 cups for €4. The large pack costs €4.50, even if each cup is cheaper."
    },
    {
      "id": "coupon",
      "title": "Read the tiny print",
      "prompt": "Your basket is €18 before delivery. Which coupon can you use?",
      "icon": "🎟️",
      "options": [
        {
          "label": "SAVE3",
          "detail": "€3 off · items subtotal at least €20",
          "badge": "Delivery doesn’t count"
        },
        {
          "label": "SAVE2",
          "detail": "€2 off · items subtotal at least €15",
          "badge": "Delivery doesn’t count"
        }
      ],
      "answer": 1,
      "explanation": "An €18 items subtotal meets the €15 minimum for SAVE2, but not the €20 minimum for SAVE3."
    },
    {
      "id": "refill",
      "title": "Keep the bottle",
      "prompt": "You already own the bottle. Which option costs less per 500 ml of soap?",
      "icon": "🧴",
      "options": [
        {
          "label": "Fresh bottle",
          "detail": "500 ml for €3",
          "badge": "Ready to use"
        },
        {
          "label": "Refill pouch",
          "detail": "1 litre for €5",
          "badge": "Same soap"
        }
      ],
      "answer": 1,
      "explanation": "The refill contains two lots of 500 ml, so each costs €2.50. The fresh bottle costs €3 per 500 ml."
    },
    {
      "id": "subscription",
      "title": "Just one movie night",
      "prompt": "You will use the service for exactly 1 month. Which plan has the lower total cost?",
      "icon": "🍿",
      "options": [
        {
          "label": "Monthly pass",
          "detail": "€7 · no setup fee",
          "badge": "Cancel after 1 month"
        },
        {
          "label": "Starter deal",
          "detail": "€4 for month 1 + €5 setup",
          "badge": "Cancel after 1 month"
        }
      ],
      "answer": 0,
      "explanation": "The monthly pass costs €7. The starter deal costs €4 + €5 = €9 for that single month."
    },
    {
      "id": "returns",
      "title": "The jacket might go back",
      "prompt": "Both jackets cost €30, with free delivery and a full item-price refund. If you return it, which shop costs you less?",
      "icon": "🧥",
      "options": [
        {
          "label": "Shop A",
          "detail": "Return postage: €4",
          "badge": "€30 item refund"
        },
        {
          "label": "Shop B",
          "detail": "Free returns",
          "badge": "€30 item refund"
        }
      ],
      "answer": 1,
      "explanation": "Shop B refunds the €30 with no return cost. At Shop A, you still pay €4 return postage."
    }
  ]
}
$quiz$::jsonb) on conflict(version) do nothing;
commit;
