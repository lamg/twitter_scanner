#!/usr/bin/env sh

sqlite3 db.sqlite3 < ./db_schema.sql
sqlite3 db.sqlite3 < ./init.sql
