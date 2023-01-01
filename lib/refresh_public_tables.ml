open Shared

let populate_tweets_by_query ctx =
  [%rapper
    execute
      {sql|
      WITH qt AS (SELECT tweet_query, total FROM tweets_by_query_view)
      UPDATE tweets_by_query SET total = qt.total
      FROM qt WHERE tweets_by_query.tweet_query = qt.tweet_query|sql}]
    ()
  |> do_query ctx.db_ctx.db_uri
;;

let populate_authors_by_age ctx =
  [%rapper
    execute
      {sql|
      WITH qa AS (SELECT tweet_query, age FROM query_authors_by_age_view)
      UPDATE query_authors_by_age SET age_in_days = qa.age
      FROM qa WHERE query = qa.tweet_query|sql}]
    ()
  |> do_query ctx.db_ctx.db_uri
;;

let main ctx =
  let _ = populate_authors_by_age ctx in
  populate_tweets_by_query ctx
;;
