(lang dune 3.6)

(name twitter_scanner)

(generate_opam_files true)

(source
 (github lamg/twitter_scanner))

(authors "Luis Ángel Méndez Gort")

(maintainers "Luis Ángel Méndez Gort")

(license GPLv3)

(documentation https://github.com/lamg/twitter_scanner)

(package
 (name twitter_scanner)
 (synopsis "Twitter scanner")
 (description "Scans tweets by query and author")
 (depends ocaml dune yojson sqlite3 ppx_deriving
          ppx_yojson_conv io_layer caqti-driver-sqlite3 ppx_rapper)
 (tags
  (topics Twitter HTTP client)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
