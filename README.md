# 智付通金流與電子發票 API Wrapper

Fork from https://github.com/CalvertYang/spgateway

基於原本的 Gem 架構，再增加智付通電子發票的 API wrapper。智付通公司的電子發票需要在 ezPay 上申請， API 相關文件可參考 [ezPay 幫助中心](https://inv.ezpay.com.tw/Invoice_index/download)。

## 安裝

```rb
# in gemfile
gem 'spgateway_payment_and_invoice_client', github: 'oracle-design/spgateway_payment_and_invoice', branch: 'master'
```

## 使用

```ruby
test_client = Spgateway::Client.new({
  merchant_id: 'MERCHANT_ID',
  hash_key: 'HASH_KEY',
  hash_iv: 'HASH_IV',
  mode: :test
})

test_invoice_client = Spgateway::InvoiceClient.new({
  merchant_id: 'MERCHANT_ID',
  hash_key: 'HASH_KEY',
  hash_iv: 'HASH_IV',
  mode: :test
})

# use mode: :production in production env

test_client.query_trade_info({
  MerchantOrderNo: '4e19cab1',
  Amt: 100
})
```

## License

MIT

![Analytics](https://ga-beacon.appspot.com/UA-44933497-3/CalvertYang/spgateway?pixel)
