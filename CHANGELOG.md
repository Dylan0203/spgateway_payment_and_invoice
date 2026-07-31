# Changelog

All notable changes to this project are documented in this file.

## 1.0.10 — 2026-07-31

### Fixed

- Replaced the three remaining `URI.decode(...)` call sites in
  `lib/spgateway/client.rb` with `URI::DEFAULT_PARSER.unescape(...)`:
  - `:71` — `#query_trade_info`
  - `:93` — `#credit_card_deauthorize`
  - `:135` — `#credit_card_collect_refund`

  `URI.decode` was removed in Ruby 3.0 alongside `URI.encode`. 1.0.9 fixed only
  the *request*-building direction, so on Ruby 3.x these methods completed the
  HTTP round trip and then raised `NoMethodError` while parsing the **response**.
  Consumers affected: any caller of `query_trade_info`,
  `credit_card_deauthorize{,_by_merchant_order_no,_by_trade_no}` and
  `credit_card_collect_refund{,_by_merchant_order_no,_by_trade_no}`.

  Note that `NEED_CHECK_VALUE_APIS` gates the *request* path only, so
  `query_trade_info` — the one method that avoids the 1.0.9 encode sites — was
  **not** exempt from this defect.

### Why `URI::DEFAULT_PARSER.unescape` and not `URI.decode_www_form`

`URI::DEFAULT_PARSER.unescape` is the exact behavioural successor to the removed
`URI.decode`: it percent-decodes and leaves a literal `+` alone.
`URI.decode_www_form` / `CGI.unescape` additionally convert `+` to a space:

```ruby
URI::DEFAULT_PARSER.unescape("a%20b+c")  # => "a b+c"   (what URI.decode did)
CGI.unescape("a%20b+c")                  # => "a b c"
```

Strictly, these responses are `application/x-www-form-urlencoded` and `+` ought
to mean space, so `decode_www_form` is the more spec-correct parser. It is
deliberately **not** used here: it is a behaviour change on values that flow
into payment business logic (order numbers, gateway messages), and this release
exists to close a crash without altering any parsed value. Migrating to
`decode_www_form` is worth doing as its own change, with its own evidence.

### Verification

Re-verified against the real NewebPay **sandbox** (`ccore.newebpay.com`, mode
`:test`, `MS`-prefixed sandbox merchant id — never a production host) from a
consuming Rails application on Ruby 3.4.10, calling the **public** method rather
than reaching past it:

```
before (1.0.9): NoMethodError: undefined method 'decode' for module URI
after:          Hash, Status="SUCCESS", 14 keys
                (TradeNo, TradeStatus, PaymentType, PayTime, CheckCode, …)
```

### Correction to the 1.0.9 entry below

The 1.0.9 note says "this gem's own spec suite stubs the HTTP calls". **This gem
has no test suite** — there is no `spec/` or `test/` directory, and the
`Rake::TestTask` in the `Rakefile` points at a `test/**/*_test.rb` glob that
matches nothing. The conclusion it was supporting still stands, and more
strongly: a sandbox round trip is the only gate this gem has.

## 1.0.9 — 2026-07-30

### Fixed

- Replaced all four remaining `URI.encode(...)` call sites with
  `URI.encode_www_form(params)`. `URI.encode` was removed in Ruby 3.0, so every
  credit-card collect / refund / deauthorize, every ezpay invoice operation,
  and every LINE Pay request raised `NoMethodError` on Ruby 3.x:
  - `lib/spgateway/client.rb` (private `#request`)
  - `lib/spgateway/invoice_client.rb` (`#invoice_search_by_invoice_no`, `offsite: true`, and private `#request`)
  - `lib/spgateway/line_pay_client.rb` (private `#request`)

  The replacement matches the form already used correctly elsewhere in this
  repository (`client_v2.rb`'s `generate_mpg_params`,
  `generate_credit_card_period_params`, and the LINE Pay refund branch).

### Why this needed more than a green test suite

`URI.encode` and `URI.encode_www_form` differ in how they treat spaces, `+` and
reserved characters, and SPGateway's `CheckValue` / ezpay's `CheckCode` is a
hash of the **encoded** query string — so a change in encoding changes the
signature. This gem's own spec suite stubs the HTTP calls and cannot catch a
signature defect. Before tagging this release, the fix was re-verified against
the real NewebPay / ezpay **sandbox** (not production) from a consuming Rails
application. See that application's
`docs/upgrade-hardening/SANDBOX-VERIFICATION.md` for the recorded request,
computed check value, sandbox endpoint, and verbatim gateway response for each
flow that could be reached from that environment.

### Known follow-up (out of scope for this release)

`lib/spgateway/client.rb` separately calls `URI.decode` (also removed in
Ruby 3) when parsing gateway **responses** for `query_trade_info`,
`credit_card_deauthorize` and `credit_card_collect_refund`
(lines 71, 93, 135). That is a distinct defect — response decoding, not
request encoding — from the one this release fixes, and is left for a
follow-up release so this change stays attributable to one root cause.

### Why this release lives on a fork

The upstream `oracle-design/spgateway_payment_and_invoice` repository is
read-only for this account (`{pull: true, push: false}`), so `1.0.9` is
tagged here on `Dylan0203/spgateway_payment_and_invoice` instead. A PR
carrying the identical fix is open upstream:
<https://github.com/oracle-design/spgateway_payment_and_invoice/pull/7>.
Once that merges, downstream consumers should move back onto an
`oracle-design` tag rather than staying on this fork.

This fork's `master` was confirmed at the same commit as upstream `master`
(`cde83d3`) immediately before this fix was applied, so moving a consumer onto
this fork reverts nothing relative to upstream.
