# Changelog

## Unreleased

## v0.2.1

* Bug fixes
  * Change category of check from `:custom` to `:warning` so that exit status > 0 if the check fails

## v0.2.0

* Bug fixes
  * Add `Base` `Atom` `String.Chars` `Tuple` to the list of pure stdlibs

* Enhancements
  * Allow for stdlib modules to marked as partially pure - e.g. `DateTime.utc_now`

* Other
  * Only check *.ex files

## v0.1.0

* Original release
