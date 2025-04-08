Ghostferry
==========

Ghostferry is a library that enables you to selectively copy data from one mysql instance to another with minimal amount of downtime.

It is inspired by Github's [gh-ost](https://github.com/github/gh-ost),
although instead of copying data from and to the same database, Ghostferry
copies data from one database to another and has the ability to only
partially copy data.

There is an example application called ghostferry-copydb included (under the
`copydb` directory) that demonstrates this library by copying an entire
database from one machine to another.

Talk to us on IRC at [irc.freenode.net #ghostferry](https://webchat.freenode.net/?channels=#ghostferry).

- **Tutorial and General Documentations**: https://shopify.github.io/ghostferry
- Code documentations: https://godoc.org/github.com/Shopify/ghostferry

Overview of How it Works
------------------------

An overview of Ghostferry's high-level design is expressed in the [TLA+
specification](https://en.wikipedia.org/wiki/TLA%2B), under the `tlaplus` directory. It may be good to consult with
that as it has a concise definition. However, the specification might not be
entirely correct as proofs remain elusive.

On a high-level, Ghostferry is broken into several components, enabling it to
copy data. This is documented at
https://shopify.github.io/ghostferry/main/technicaloverview.html

Development Setup
-----------------

### Installation

#### For Internal Contributors

`dev up`

#### For External Contributors

- Have Docker installed
- Clone the repo
- `docker-compose up -d`
- `nix-shell`

Testing
---------------

#### Run all tests

- `make test`

#### Run example copydb usage

- `make copydb && ghostferry-copydb -verbose examples/copydb/conf.json`
- For a more detailed tutorial, see the
  [documentation](https://shopify.github.io/ghostferry).

### Ruby Integration Tests

Kindly take note of following options:

- `DEBUG=1`: To see more detailed debug output by `Ghostferry` live, as opposed
  to only when the test fails. This is helpful for debugging hanging test.

Examples:

Run all tests

`rake test`

Run a single file

`rake test TEST=test/integration/trivial_test.rb`

or

`ruby -Itest test/integration/trivial_test.rb`

Run a specific test

`DEBUG=1 ruby -Itest test/integration/trivial_test.rb -n "TrivialIntegrationTest#test_logged_query_omits_columns"`
