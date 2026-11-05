-- รันทั้งไฟล์ใน Supabase > SQL Editor
create table seniors(id text primary key,name text not null,hint text not null default '',capacity int not null default 1 check(capacity in(1,2)));
create table juniors(id text primary key,name text not null);
create table matches(junior_id text primary key references juniors(id) on delete cascade,senior_id text not null references seniors(id) on delete restrict,created_at timestamptz default now());
alter table seniors enable row level security;alter table juniors enable row level security;alter table matches enable row level security;
create policy a on seniors for all to authenticated using(true) with check(true);
create policy a on juniors for all to authenticated using(true) with check(true);
create policy a on matches for select to authenticated using(true);

create function chk_cap() returns trigger language plpgsql as $$
declare cap int;c int;begin
 select capacity into cap from seniors where id=new.senior_id for update;
 select count(*) into c from matches where senior_id=new.senior_id;
 if c>=cap then raise exception 'พี่ % เต็มโควตาแล้ว',new.senior_id;end if;return new;end $$;
create trigger t_cap before insert on matches for each row execute function chk_cap();
create function chk_cap_down() returns trigger language plpgsql as $$
begin if new.capacity<(select count(*) from matches where senior_id=new.id) then raise exception 'ลดโควตาไม่ได้ พี่คนนี้มีน้องมากกว่านั้นแล้ว';end if;return new;end $$;
create trigger t_cap2 before update of capacity on seniors for each row execute function chk_cap_down();

-- น้องดูได้เฉพาะคำใบ้ของพี่ตัวเอง (ไม่เปิดเผยรายชื่อคู่)
create function get_letter(p_id text) returns jsonb language sql security definer set search_path=public as $$
 select case when not exists(select 1 from juniors where id=p_id) then '{"status":"not_found"}'::jsonb
  else coalesce((select jsonb_build_object('status','ok','hint',s.hint) from matches m join seniors s on s.id=m.senior_id where m.junior_id=p_id),'{"status":"unmatched"}'::jsonb) end $$;
grant execute on function get_letter(text) to anon,authenticated;

-- สุ่มตัวอย่าง (ยังไม่บันทึก): เฉพาะน้องที่ยังไม่มีคู่ ใช้เฉพาะโควตาที่เหลือ พี่ที่ยังไม่มีน้องได้ก่อน
create function preview_matching() returns jsonb language plpgsql security definer set search_path=public as $$
declare need int;have int;begin
 if auth.role()<>'authenticated' then raise exception 'forbidden';end if;
 select count(*) into need from juniors where id not in(select junior_id from matches);
 select coalesce(sum(s.capacity-coalesce(m.c,0)),0) into have from seniors s left join(select senior_id,count(*) c from matches group by 1)m on m.senior_id=s.id;
 if have<need then raise exception 'โควตาไม่พอ: ต้องจับ % คน แต่เหลือที่ว่าง % ที่ (ขาดอีก %) — เพิ่มพี่ที่รับน้อง 2 คน',need,have,need-have;end if;
 return(with j as(select id,row_number() over(order by random()) rn from juniors where id not in(select junior_id from matches)),
  slots as(select s.id sid,g from seniors s left join(select senior_id,count(*) c from matches group by 1)m on m.senior_id=s.id,generate_series(coalesce(m.c,0)+1,s.capacity) g),
  r as(select sid,row_number() over(order by g,random()) rn from slots)
  select coalesce(jsonb_agg(jsonb_build_object('senior_id',r.sid,'junior_id',j.id)),'[]'::jsonb) from j join r using(rn));end $$;

-- ยืนยัน: บันทึกทั้งชุดในธุรกรรมเดียว ถ้าซ้ำ/โควตาเต็มจะ rollback ทั้งหมด ไม่ทับคู่เดิม
create function confirm_matching(pairs jsonb) returns int language plpgsql security definer set search_path=public as $$
declare p jsonb;n int:=0;begin
 if auth.role()<>'authenticated' then raise exception 'forbidden';end if;
 perform pg_advisory_xact_lock(42);
 for p in select * from jsonb_array_elements(pairs) loop
  insert into matches(junior_id,senior_id) values(p->>'junior_id',p->>'senior_id');n:=n+1;end loop;return n;end $$;
revoke execute on function preview_matching(),confirm_matching(jsonb) from public,anon;
grant execute on function preview_matching(),confirm_matching(jsonb) to authenticated;
