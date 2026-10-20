"""A throwaway Postgres with Utopia's migrations applied, for testing SQL.

Stands in for the Supabase pieces the migrations use: the auth schema
(auth.users, auth.uid() from a session setting), the anon/authenticated/
service_role roles, a storage schema, the realtime publication and pg_cron.

Run every test:  python3 tool/db_test/run_all.py  (pip install -r
tool/db_test/requirements.txt first). A test does
`db = harness.fresh()` for a database with every migration applied, then
`harness.as_user(db, harness.new_user(db))` to call functions as a player.
"""
import glob
import os
import re
import shutil
import sys
import tempfile

import pgserver
import psycopg2

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

SHIM = r"""
do $$ begin
  create role anon nologin; exception when duplicate_object then null; end $$;
do $$ begin
  create role authenticated nologin; exception when duplicate_object then null; end $$;
do $$ begin
  create role service_role nologin bypassrls; exception when duplicate_object then null; end $$;
create schema if not exists auth;
create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text,
  is_anonymous boolean default false,
  raw_user_meta_data jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);
create or replace function auth.uid() returns uuid language sql stable as
  $f$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $f$;
create or replace function auth.role() returns text language sql stable as
  $f$ select coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), 'anon') $f$;
create or replace function auth.jwt() returns jsonb language sql stable as
  $f$ select coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb,
                      '{}'::jsonb) $f$;
create schema if not exists storage;
create table if not exists storage.buckets (
  id text primary key, name text, public boolean default false,
  file_size_limit bigint, allowed_mime_types text[]
);
create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(), bucket_id text, name text,
  owner uuid, metadata jsonb, created_at timestamptz default now()
);
alter table storage.objects enable row level security;
create or replace function storage.foldername(name text) returns text[]
  language sql immutable as $f$ select string_to_array(name, '/') $f$;
create or replace function storage.filename(name text) returns text
  language sql immutable as $f$ select (string_to_array(name, '/'))[cardinality(string_to_array(name, '/'))] $f$;
create or replace function storage.extension(name text) returns text
  language sql immutable as $f$ select reverse(split_part(reverse(name), '.', 1)) $f$;
create schema if not exists extensions;
-- pgcrypto isn't in the bundled Postgres: a stand-in for crypt() and
-- gen_salt() that behaves the same way (crypt(password, stored) = stored
-- for the right password), hashing with sha256.
create or replace function extensions.gen_salt(kind text, rounds int default 6)
  returns text language sql volatile as
  $f$ select '$shim$' || substr(md5(random()::text), 1, 16) $f$;
create or replace function extensions.crypt(password text, salt text)
  returns text language sql immutable as
  $f$ select '$shim$' || substr(salt, 7, 16)
             || encode(sha256(convert_to(substr(salt, 7, 16) || password, 'UTF8')), 'hex') $f$;
create schema if not exists cron;
create table if not exists cron.job (jobid serial, jobname text, schedule text, command text);
create or replace function cron.schedule(name text, sched text, cmd text) returns bigint
  language sql as $f$ insert into cron.job (jobname, schedule, command) values (name, sched, cmd) returning jobid $f$;
create or replace function cron.unschedule(name text) returns boolean
  language sql as $f$ delete from cron.job where jobname = name returning true $f$;
do $$ begin
  create publication supabase_realtime; exception when duplicate_object then null; end $$;
grant usage on schema public to anon, authenticated, service_role;
-- Supabase's defaults: the API roles get everything on new public objects,
-- and row level security (plus explicit revokes) narrows it.
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
grant usage on schema auth to anon, authenticated, service_role;
"""


def _prepare(sql):
    # pg_cron and pgcrypto aren't in the bundled Postgres; the cron schema
    # and the crypt functions above stand in.
    return re.sub(r"create extension if not exists (pg_cron|pgcrypto)[^;]*;", "",
                  sql, flags=re.I)


_server = None


def fresh(repo=REPO, upto=None):
    """A new database with the migrations applied (up to and including the
    file named [upto], if given). Returns an autocommit connection."""
    global _server
    if _server is None:
        _server = pgserver.get_server(tempfile.mkdtemp(prefix="utopia_pg_"),
                                      cleanup_mode="stop")
    name = "t%d" % os.getpid()
    admin = psycopg2.connect(_server.get_uri())
    admin.autocommit = True
    with admin.cursor() as c:
        c.execute(f"drop database if exists {name}")
        c.execute(f"create database {name}")
    db = psycopg2.connect(_server.get_uri(), dbname=name)
    db.autocommit = True
    with db.cursor() as c:
        c.execute(SHIM)
    for path in sorted(glob.glob(os.path.join(repo, "supabase/migrations/*.sql"))):
        with db.cursor() as c:
            try:
                c.execute("begin")
                c.execute(_prepare(open(path).read()))
                c.execute("commit")
            except Exception as e:
                c.execute("rollback")
                raise RuntimeError(f"{os.path.basename(path)}: {e}") from e
        if upto and os.path.basename(path).startswith(upto):
            break
    return db


def as_user(db, uid, claims=None):
    """Calls after this run as [uid] (an authenticated player), with the
    session's token holding [claims] too (e.g. its amr)."""
    import json
    with db.cursor() as c:
        c.execute("reset role")
        c.execute("select set_config('request.jwt.claim.sub', %s, false)", (uid,))
        c.execute("select set_config('request.jwt.claim.role', 'authenticated', false)")
        c.execute("select set_config('request.jwt.claims', %s, false)",
                  (json.dumps({"sub": uid, "role": "authenticated", **(claims or {})}),))
        c.execute("set role authenticated")


def as_admin(db):
    with db.cursor() as c:
        c.execute("reset role")
        c.execute("select set_config('request.jwt.claim.sub', '', false)")
        c.execute("select set_config('request.jwt.claims', '', false)")


def new_user(db, email=None):
    as_admin(db)
    with db.cursor() as c:
        c.execute("insert into auth.users (email, is_anonymous) values (%s, %s) returning id",
                  (email, email is None))
        return str(c.fetchone()[0])


if __name__ == "__main__":
    fresh()
    print("OK: every migration applied")
