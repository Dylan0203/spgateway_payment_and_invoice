# frozen_string_literal: true

require 'net/http'
require 'cgi'
require 'digest'
require 'spgateway/errors'
require 'spgateway/helpers'
require 'spgateway/core_ext/hash'
module Spgateway
  # Base on NDNF-1.0.7 & NDNP-1.0.1
  class ClientV2 # :nodoc:
    include Spgateway::Helpers

    NORMAL_PAYMENT_API_END_POINTS = {
      test: 'https://ccore.newebpay.com/MPG/mpg_gateway',
      production: 'https://core.newebpay.com/MPG/mpg_gateway'
    }.freeze
    SUBSCRIPTION_API_END_POINTS = {
      test: 'https://ccore.newebpay.com/MPG/period',
      production: 'https://core.newebpay.com/MPG/period'
    }.freeze

    TRANSACTION_API_ENDPOINTS = {
      test: 'https://ccore.newebpay.com/API/QueryTradeInfo',
      production: 'https://core.newebpay.com/API/QueryTradeInfo'
    }.freeze
    CREDITCARD_COLLECT_REFUND_API_ENDPOINTS = {
      test: 'https://ccore.newebpay.com/API/CreditCard/Close',
      production: 'https://core.newebpay.com/API/CreditCard/Close'
    }.freeze
    CREDITCARD_DEAUTHORIZE_API_ENDPOINTS = {
      test: 'https://ccore.newebpay.com/API/CreditCard/Cancel',
      production: 'https://core.newebpay.com/API/CreditCard/Cancel'
    }.freeze
    SUBSCRIPTION_ALTERSTATUS_API_ENDPOINT = {
      test: 'https://ccore.newebpay.com/MPG/period/AlterStatus',
      production: 'https://core.newebpay.com/MPG/period/AlterStatus'
    }.freeze
    E_WALLET_REFUND_API_ENDPOINT = {
      test: 'https://ccore.newebpay.com/API/EWallet/refund',
      production: 'https://core.newebpay.com/API/EWallet/refund'
    }.freeze

    attr_reader :options, :mode, :merchant_id, :hash_key, :hash_iv

    def initialize(options = {})
      @options = { mode: :production }.merge!(options)
      @mode = @options[:mode]

      case mode
      when :test, :production
        option_required! :merchant_id, :hash_key, :hash_iv
      else
        raise InvalidMode, %(option :mode is either :test or :production)
      end

      @merchant_id = @options[:merchant_id]
      @hash_key = @options[:hash_key]
      @hash_iv = @options[:hash_iv]

      @options.freeze
    end

    def generate_mpg_params(params = {})
      param_required! params, %i[MerchantOrderNo Amt ItemDesc]

      post_params = {
        MerchantID: merchant_id,
        RespondType: 'JSON',
        TimeStamp: Time.now.to_i,
        Version: '2.0'
      }.merge!(params)

      trade_info = encode_post_data(URI.encode_www_form(post_params))

      {
        MerchantID: merchant_id,
        TradeInfo: trade_info,
        TradeSha: make_check_value(:mpg20, trade_info),
        Version: '2.0'
      }
    end

    def generate_credit_card_period_params(params = {})
      param_required! params, %i[
        MerOrderNo
        ProdDesc
        PeriodAmt
        PeriodType
        PeriodPoint
        PeriodStartType
        PeriodTimes
        ReturnURL
        PayerEmail
        NotifyURL
        BackURL
      ]

      post_params = {
        RespondType: 'JSON',
        TimeStamp: Time.now.to_i,
        Version: '1.5'
      }.merge!(params)

      {
        MerchantID_: merchant_id,
        PostData_: encode_post_data(URI.encode_www_form(post_params))
      }
    end

    def change_subscription_status(params = {})
      param_required! params, %i[MerOrderNo PeriodNo AlterType]

      post_params = {
        Version: '1.0',
        RespondType: 'JSON',
        TimeStamp: Time.now.to_i
      }.merge!(params)

      res = request :change_subscription_status, post_params

      JSON.parse res.body
    end

    def query_trade_info(params = {})
      param_required! params, %i[MerchantOrderNo Amt]

      post_params = {
        Version: '1.3',
        RespondType: 'JSON',
        TimeStamp: Time.now.to_i
      }.merge!(params)

      res = request :query_trade_info, post_params

      JSON.parse res.body
    end

    def credit_card_deauthorize(params = {})
      param_required! params, %i[Amt IndexType]

      unless [params[:MerchantOrderNo], params[:TradeNo]].any?
        raise MissingOption, %(One of the following param is required: MerchantOrderNo, TradeNo)
      end

      post_params = {
        RespondType: 'JSON',
        Version: '1.0',
        TimeStamp: Time.now.to_i
      }.merge!(params)

      res = request :credit_card_deauthorize, post_params

      JSON.parse res.body
    end

    def credit_card_deauthorize_by_merchant_order_no(params = {})
      param_required! params, %i[Amt MerchantOrderNo]

      post_params = {
        IndexType: 1
      }.merge!(params)

      credit_card_deauthorize post_params
    end

    def credit_card_deauthorize_by_trade_no(params = {})
      param_required! params, %i[Amt TradeNo]

      post_params = {
        IndexType: 2
      }.merge!(params)

      credit_card_deauthorize post_params
    end

    def credit_card_collect_refund(params = {})
      param_required! params, %i[Amt IndexType CloseType]

      unless [params[:MerchantOrderNo], params[:TradeNo]].any?
        raise MissingOption, %(One of the following param is required: MerchantOrderNo, TradeNo)
      end

      post_params = {
        RespondType: 'JSON',
        Version: '1.1',
        TimeStamp: Time.now.to_i
      }.merge!(params)

      res = request :credit_card_collect_refund, post_params

      JSON.parse res.body
    end

    def credit_card_collect_by_merchant_order_no(params = {})
      param_required! params, %i[Amt MerchantOrderNo]

      post_params = {
        IndexType: 1,
        CloseType: 1
      }.merge!(params)

      credit_card_collect_refund post_params
    end

    def credit_card_collect_by_trade_no(params = {})
      param_required! params, %i[Amt TradeNo]

      post_params = {
        IndexType: 2,
        CloseType: 1
      }.merge!(params)

      credit_card_collect_refund post_params
    end

    def credit_card_refund_by_merchant_order_no(params = {})
      param_required! params, %i[Amt MerchantOrderNo]

      post_params = {
        IndexType: 1,
        CloseType: 2
      }.merge!(params)

      credit_card_collect_refund post_params
    end

    def credit_card_refund_by_trade_no(params = {})
      param_required! params, %i[Amt TradeNo]

      post_params = {
        IndexType: 2,
        CloseType: 2
      }.merge!(params)

      credit_card_collect_refund post_params
    end

    def ewallet_refund_by_merchant_order_no(params = {})
      param_required! params, %i[Amount PaymentType MerchantOrderNo]

      post_params = {
        TimeStamp: Time.now.to_i
      }.merge!(params)

      res = request :ewallet_refund, post_params

      JSON.parse res.body
    end

    def api_url_for(type)
      result = {
        mpg: NORMAL_PAYMENT_API_END_POINTS[mode],
        period: SUBSCRIPTION_API_END_POINTS[mode],
        query_trade_info: TRANSACTION_API_ENDPOINTS[mode],
        credit_card_deauthorize: CREDITCARD_DEAUTHORIZE_API_ENDPOINTS[mode],
        credit_card_collect_refund: CREDITCARD_COLLECT_REFUND_API_ENDPOINTS[mode],
        change_subscription_status: SUBSCRIPTION_ALTERSTATUS_API_ENDPOINT[mode],
        ewallet_refund: E_WALLET_REFUND_API_ENDPOINT[mode]
      }[type]

      raise UnsupportedType, 'Unsupported API type.' unless result

      result
    end

    def decode_json_data(data)
      JSON.parse(decode_aes_data(data))
    end

    private

    def request(type, params = {})
      post_params = case type
                    when :query_trade_info
                      generate_params(type, params)
                    when :ewallet_refund
                      encode_data = encode_post_data(params.to_json)
                      {
                        UID_: merchant_id,
                        Version_: '1.0',
                        RespondType_: 'JSON',
                        EncryptData_: encode_data,
                        HashData_: make_check_value(:line_pay_refund, encode_data)
                      }
                    else
                      {
                        MerchantID_: merchant_id,
                        PostData_: encode_post_data(URI.encode_www_form(params))
                      }
                    end

      Net::HTTP.post_form(
        URI(
          api_url_for(type)
        ),
        post_params
      )
    end
  end
end
