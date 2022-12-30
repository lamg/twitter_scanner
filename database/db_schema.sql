CREATE TABLE query (
  id integer NOT NULL,
  tweet_query text NOT NULL,
  start_date text NOT NULL
);

-- association between a tweet and the query that found it
CREATE TABLE query_tweet (
  query_id integer NOT NULL,
  tweet_id text NOT NULL,
  seen integer NOT NULL,
  UNIQUE (query_id, tweet_id)
);

-- fields common to all kinds of tweets
CREATE TABLE base_tweet (
  id text NOT NULL,
  author_id text NOT NULL,
  created_at text NOT NULL,
  UNIQUE (id)
);

-- original tweets (i.e. not retweeted or cited)
CREATE TABLE original_tweet (
  id text NOT NULL,
  tweet_text text NOT NULL,
  UNIQUE (id)
);

CREATE TABLE reference_tweet (
  id text NOT NULL,
  reference_id text NOT NULL,
  reference_type text NOT NULL,
  UNIQUE (id)
);

--
-- record of scans section
-- how many tweets returned a query at a point in time
CREATE TABLE scanning (
  query_id integer NOT NULL,
  scan_date text NOT NULL,
  amount integer NOT NULL
);

--
CREATE TABLE failed_request (
  id INTEGER NOT NULL,
  performed_at TEXT NOT NULL,
  url TEXT NOT NULL,
  code INTEGER NOT NULL,
  body TEXT NOT NULL
);

CREATE TABLE failed_decode (
  request_id INTEGER NOT NULL
);

CREATE TABLE failed_profile_update(
request_id INTEGER NOT NULL,
profile_id TEXT NOT NULL
);

CREATE TABLE failed_query(
query_id INTEGER NOT NULL,
request_id INTEGER NOT NULL
);

-- profiles section
CREATE TABLE profile (
  id text NOT NULL,
  name text NOT NULL,
  created_at text NOT NULL,
  username text NOT NULL,
  location text NOT NULL,
  UNIQUE (id)
);


CREATE TABLE profile_location (
  profile_id text NOT NULL,
  location text NOT NULL,
  UNIQUE (profile_id)
);

CREATE TABLE watched_profile (
  id text NOT NULL,
  started_at text NOT NULL,
  UNIQUE (id)
);

CREATE TABLE oldest_timeline_tweet (
  profile_id text NOT NULL,
  tweet_id text NOT NULL,
  UNIQUE (profile_id)
);

-- view for creating a batch of the next profiles to be updated
CREATE VIEW update_profile_batch AS
SELECT
  0 AS id,
  profile_id
FROM
  profiles_to_update
LIMIT 100;

--
CREATE VIEW profiles_to_update AS
SELECT
  author_id AS profile_id
FROM
  base_tweet
WHERE
  author_id NOT IN (
    SELECT
      id
    FROM
      profile)
  AND author_id NOT IN (
    SELECT
      profile_id
    FROM
      profile_deactivated);

-- profile whose information couldn't be retrieved as part of an update
CREATE TABLE profile_deactivated (
  profile_id text NOT NULL,
  noticed_at text NOT NULL,
  status text NOT NULL,
  UNIQUE (profile_id)
);

-- configuration section
CREATE TABLE token (
  id integer NOT NULL,
  bearer text NOT NULL,
  app_name text NOT NULL,
  tweets_per_month integer NOT NULL,
  ref_date text NOT NULL,
  UNIQUE (id)
);
