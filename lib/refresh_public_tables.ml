open Shared

let delete_authors_by_age ctx =
  [%rapper execute {sql| DELETE FROM query_authors_by_age |sql}] ()
  |> do_query ctx.db_ctx.db_uri
;;

let delete_tweets_by_query ctx =
  [%rapper execute {sql| DELETE FROM tweets_by_query |sql}] ()
  |> do_query ctx.db_ctx.db_uri
;;

let populate_tweets_by_query ctx =
  [%rapper
    execute
      {sql|
      INSERT INTO tweets_by_query(tweet_query, total)
      SELECT tweet_query, total FROM tweets_by_query_view |sql}]
    ()
  |> do_query ctx.db_ctx.db_uri
;;

let populate_authors_by_age ctx =
  [%rapper
    execute
      {sql|
      INSERT INTO query_authors_by_age(query, age_in_days)
      SELECT tweet_query, age FROM query_authors_by_age_view |sql}]
    ()
  |> do_query ctx.db_ctx.db_uri
;;

let main ctx =
  delete_authors_by_age ctx;
  delete_tweets_by_query ctx;
  populate_authors_by_age ctx;
  populate_tweets_by_query ctx
;;
