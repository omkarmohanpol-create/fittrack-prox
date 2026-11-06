#!/bin/bash
# Runs supabase/schema.sql twice on a throwaway PostgreSQL database with
# stand-ins for Supabase's auth/storage schemas, then the behaviour tests.
# Needs psql and a server you can create databases on, for example:
#   PGHOST=localhost PGUSER=postgres supabase/tests/run.sh
set -euo pipefail
cd "$(dirname "$0")"
DB=fittrack_schema_test_$$
createdb "$DB"
trap 'dropdb --if-exists "$DB"' EXIT
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f supabase_stubs.sql
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f ../schema.sql >/dev/null 2>&1
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f ../schema.sql >/dev/null 2>&1
echo "schema.sql: ran twice"
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f schema_test.sql
