{-
Welcome to a Spago project!
You can edit this file as you like.
-}
{ name = "my-project"
, dependencies =
  [ "console"
  , "effect"
  , "lists"
  , "node-fs"
  , "parsing"
  , "psci-support"
  , "result"
  , "tuples"
  , "unicode"
  ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs", "test/**/*.purs" ]
}
