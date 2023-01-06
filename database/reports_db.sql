CREATE TABLE tweets_by_query(
tweet_query TEXT NOT NULL,
total INTEGER NOT NULL,
UNIQUE(tweet_query)
);

CREATE TABLE query_authors_by_age(
tweet_query TEXT NOT NULL,
age_in_days INTEGER NOT NULL,
UNIQUE(tweet_query)
);

CREATE TABLE totals(
tweets INTEGER NOT NULL,
profiles INTEGER NOT NULL
);

INSERT INTO totals VALUES (0,0);

CREATE TABLE latest_scan(
tweet_query TEXT NOT NULL,
scanned_at TEXT NOT NULL,
amount INTEGER NOT NULL,
UNIQUE(tweet_query)
);

CREATE TABLE profiles_created_by_query(
tweet_query TEXT NOT NULL,
month INTEGER NOT NULL,
year INTEGER NOT NULL,
amount INTEGER NOT NULL,
UNIQUE(tweet_query,month,year)
);
