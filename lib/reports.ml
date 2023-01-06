open! Core
open Shared
open Io_layer

let update_tweets_by_query (main_db : Db.context) (reports_db : Db.context) =
  [%rapper
    get_many
      {sql|
      SELECT @string{tweet_query}, @int{total} FROM tweets_by_query_view
      |sql}]
    ()
  |> do_query main_db.db_uri
  |> List.iter ~f:(fun (tweet_query, total) ->
       [%rapper
         execute
           {sql|
        INSERT INTO tweets_by_query(tweet_query, total)
        VALUES(%string{tweet_query},%int{total})
        ON CONFLICT DO
        UPDATE SET total=%int{total} WHERE tweet_query = %int{total} |sql}]
         ~tweet_query
         ~total
       |> do_query reports_db.db_uri)
;;

let update_authors_by_age (main_db : Db.context) (reports_db : Db.context) =
  [%rapper
    get_many
      {sql|
      SELECT @string{tweet_query}, @int{age} FROM query_authors_by_age_view|sql}]
    ()
  |> do_query main_db.db_uri
  |> List.iter ~f:(fun (tweet_query, age) ->
       [%rapper
         execute
           {sql|
 INSERT INTO query_authors_by_age(tweet_query, age_in_days)
 VALUES(%string{tweet_query}, %int{age})
 ON CONFLICT(tweet_query) DO
 UPDATE SET age_in_days=%int{age}
 WHERE tweet_query=%string{tweet_query}|sql}
           syntax_off]
         ~tweet_query
         ~age
       |> do_query reports_db.db_uri)
;;

let update_totals (main_db : Db.context) (reports_db : Db.context) =
  [%rapper
    get_one
      {sql|
      SELECT (SELECT count(id) FROM base_tweet) AS @int{tweets},
      (SELECT count(id) FROM profile) AS @int{profiles}
  |sql}
      syntax_off]
    ()
  |> do_query main_db.db_uri
  |> fun (tweets, profiles) ->
  [%rapper
    execute
      {sql|UPDATE totals SET tweets=%int{tweets}, profiles=%int{profiles}|sql}]
    ~tweets
    ~profiles
  |> do_query reports_db.db_uri
;;

let update_latest_scan (main_db : Db.context) (reports_db : Db.context) =
  [%rapper execute {sql|DELETE FROM latest_scan|sql}] () |> do_query reports_db.db_uri;
  [%rapper
    get_many
      {sql|
  WITH max_date AS (SELECT strftime('%Y-%m-%dT%H:%M:00.000Z',max(scan_date)) AS max_date FROM scanning)
  SELECT @string{q.tweet_query}, @string{m.max_date}, @int{s.amount}
  FROM scanning s, query q, max_date m
  WHERE s.query_id = q.id AND s.scan_date >= m.max_date
  GROUP BY s.query_id
  ORDER BY amount DESC
  |sql}]
    ()
  |> do_query main_db.db_uri
  |> List.iter ~f:(fun (tweet_query,scan_date, amount) ->
       [%rapper
         execute
           {sql|
  INSERT INTO latest_scan(tweet_query, amount, scanned_at)
  VALUES(%string{tweet_query}, %int{amount}, %string{scan_date})
  |sql}
           syntax_off]
         ~tweet_query
         ~amount
         ~scan_date
       |> do_query reports_db.db_uri)
;;

let update_profiles_created_by_query
  (main_db : Db.context)
  (reports_db : Db.context)
  =
  [%rapper
    get_many
      {sql|
      SELECT @string{tweet_query}, @int{month}, @int{year}, @int{total}
      FROM profiles_created_by_query WHERE year >= 2022|sql} syntax_off]
    ()
  |> do_query main_db.db_uri
  |> List.iter ~f:(fun (tweet_query, month, year, amount) ->
       [%rapper
         execute
           {sql|
           INSERT INTO profiles_created_by_query
           VALUES (%string{tweet_query}, %int{month}, %int{year}, %int{amount})
           ON CONFLICT DO
           UPDATE SET amount=%int{amount}
           WHERE tweet_query=%string{tweet_query} AND month=%int{month} AND year=%int{year}
           |sql} syntax_off]
         ~tweet_query
         ~month
         ~year
         ~amount
       |> do_query reports_db.db_uri)
;;

let slow_reports (main_db : Db.context) (reports_db : Db.context) =
  update_authors_by_age main_db reports_db
;;

let fast_reports (main_db : Db.context) (reports_db : Db.context) =
  update_tweets_by_query main_db reports_db;
  update_totals main_db reports_db;
  update_latest_scan main_db reports_db;
  update_profiles_created_by_query main_db reports_db
;;
