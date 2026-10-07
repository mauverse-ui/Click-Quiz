-- Explicit user approval received 7 October 2026.
-- Permanently remove only new CQ attempts older than 90 days and dependent
-- CQ events/ballots; never quiz versions/questions or legacy tables.
create extension if not exists pg_cron with schema pg_catalog;
create or replace function public.cq_prune_analytics()
returns bigint language plpgsql security definer set search_path='' as $$
declare removed bigint;
begin
 delete from public.cq_attempts where created_at<now()-interval '90 days';
 get diagnostics removed=row_count;
 return removed;
end $$;
revoke all on function public.cq_prune_analytics() from public,anon,authenticated;
select cron.schedule('cq-analytics-retention','25 3 * * *','select public.cq_prune_analytics();');
select public.cq_prune_analytics() as old_attempts_removed;
select jobid,jobname,schedule,command,active from cron.job where jobname='cq-analytics-retention';
