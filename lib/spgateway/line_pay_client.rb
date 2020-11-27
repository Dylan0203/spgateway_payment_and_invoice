require 'net/http'
require 'openssl'
require 'json'
require 'cgi'
require 'digest'
require 'spgateway/errors'
require 'spgateway/helpers'
require 'spgateway/core_ext/hash'

module Spgateway
  class LinePayClient
    include Spgateway::Helpers

    REFUND_API_ENDPOINTS = {
      test: 'https://ccore.newebpay.com/API/LinePay/refund',
      production: 'https://core.newebpay.com/API/LinePay/refund'
    }.freeze
    NEED_CHECK_VALUE_APIS = [
      :query_trade_info # Transaction API
    ].freeze

    attr_reader :options

    def initialize(options = {})
      @options = { mode: :production }.merge!(options)

      case @options[:mode]
      when :test, :production
        option_required! :merchant_id, :hash_key, :hash_iv
      else
        raise InvalidMode, %(option :mode is either :test or :production)
      end

      @options.freeze
    end

    def refund(params = {})
      param_required! params, %i[
        MerchantOrderNo
        RefundAmount
      ]

      raw_params = {
        MerchantID: @options[:merchant_id]
      }.merge!(params)

      skip_encode_params = {
        Version: '1.0'
      }

      res = request :refund, raw_params, skip_encode_params

      reslut_hash = JSON.parse(res.body) || {}
      reslut_hash['VaildTradeInfo'] = make_check_value(:line_pay_refund, reslut_hash['TradeInfo']) == reslut_hash['TradeSha']

      return reslut_hash if reslut_hash['TradeInfo'].nil?

      if reslut_hash['TradeInfo'].start_with?("{")
        reslut_hash.merge!(JSON.parse(reslut_hash['TradeInfo']))
      else
        reslut_hash.merge!(JSON.parse(decode_aes_data(reslut_hash['TradeInfo'])))
      end

      reslut_hash
    rescue Exception => error
      reslut_hash.merge(line_pay_client_error: error)
    end

    private

    def request(type, params = {}, skip_encode_params = {})
      case type
      when :refund
        api_url = REFUND_API_ENDPOINTS[@options[:mode]]
      end

      trade_info = encode_post_data(URI.encode(params.map { |key, value| "#{key}=#{value}" }.join('&')))
      trade_sha = make_check_value(:line_pay_refund, trade_info)

      post_params = {
        MerchantID: @options[:merchant_id],
        TradeInfo: trade_info,
        TradeSha: trade_sha
      }.merge!(skip_encode_params)

      Net::HTTP.post_form URI(api_url), post_params
    end
  end
end
