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
 WHERE tweet_query=%string{tweet_query}|sql} syntax_off]
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
  |sql} syntax_off]
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
  [%rapper
    get_many
      {sql|
  SELECT @string{q.tweet_query}, @int{s.amount}, @string{s.scan_date}
  FROM scanning s, query q
  WHERE s.query_id = q.id
  ORDER BY s.amount DESC
  |sql}]
    ()
  |> do_query main_db.db_uri
  |> List.iter ~f:(fun (tweet_query, amount, scan_date) ->
       [%rapper
         execute
           {sql|
INSERT INTO latest_scan(tweet_query, amount, scanned_at)
VALUES(%string{tweet_query}, %int{amount}, %string{scan_date})
ON CONFLICT DO
UPDATE SET amount=%int{amount}, scanned_at=%string{scan_date}
WHERE tweet_query = %string{tweet_query} |sql} syntax_off]
         ~tweet_query
         ~amount
         ~scan_date
       |> do_query reports_db.db_uri)
;;

let main (main_db : Db.context) (reports_db : Db.context) =
  update_authors_by_age main_db reports_db;
  update_tweets_by_query main_db reports_db;
  update_totals main_db reports_db;
  update_latest_scan main_db reports_db
;;
