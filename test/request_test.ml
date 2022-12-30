let ok = Alcotest.(check bool) "" true
let suite_gen = [ ("dummy test", `Quick, fun _ -> ok true) ]
let () = Alcotest.run "scan" [ "scan", suite_gen ]
