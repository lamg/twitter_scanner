#!/usr/bin/env sh

rm db.sqlite3 reports.sqlite3
sqlite3 db.sqlite3 < ./db_schema.sql
sqlite3 db.sqlite3 < ./init.sql
sqlite3 reports.sqlite3 < ./reports_db.sql
