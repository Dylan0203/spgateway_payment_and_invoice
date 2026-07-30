# Changelog

All notable changes to this project are documented in this file.

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
