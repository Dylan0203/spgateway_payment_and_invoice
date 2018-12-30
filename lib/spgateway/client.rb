# frozen_string_literal: true
require 'net/http'
require 'cgi'
require 'digest'
require 'spgateway/errors'
require 'spgateway/helpers'
require 'spgateway/core_ext/hash'

module Spgateway
  class Client # :nodoc:
    include Spgateway::Helpers

    TRANSACTION_API_ENDPOINTS = {
      test: 'https://ccore.spgateway.com/API/QueryTradeInfo',
      production: 'https://core.spgateway.com/API/QueryTradeInfo'
    }.freeze
    CREDITCARD_COLLECT_REFUND_API_ENDPOINTS = {
      test: 'https://ccore.spgateway.com/API/CreditCard/Close',
      production: 'https://core.spgateway.com/API/CreditCard/Close'
    }.freeze
    CREDITCARD_DEAUTHORIZE_API_ENDPOINTS = {
      test: 'https://ccore.spgateway.com/API/CreditCard/Cancel',
      production: 'https://core.spgateway.com/API/CreditCard/Cancel'
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

    def generate_mpg_params(params = {})
      param_required! params, [:MerchantOrderNo, :Amt, :ItemDesc, :Email, :LoginType]

      post_params = {
        RespondType: 'String',
        TimeStamp: Time.now.to_i,
        Version: '1.2'
      }.merge!(params)

      generate_params(:mpg, post_params)
    end

    def query_trade_info(params = {})
      param_required! params, [:MerchantOrderNo, :Amt]

      post_params = {
        Version: '1.1',
        RespondType: 'String',
        TimeStamp: Time.now.to_i
      }.merge!(params)

      res = request :query_trade_info, post_params
      Hash[res.body.split('&').map! { |i| URI.decode(i).split('=') }]
    end

    def credit_card_deauthorize(params = {})
      param_required! params, [:Amt, :IndexType]

      raise MissingOption, %(One of the following param is required: MerchantOrderNo, TradeNo) if params[:MerchantOrderNo].nil? && params[:TradeNo].nil?

      post_params = {
        RespondType: 'String',
        Version: '1.0',
        TimeStamp: Time.now.to_i
      }.merge!(params)

      post_params.delete_if { |_, value| value.nil? }

      res = request :credit_card_deauthorize, post_params
      Hash[res.body.split('&').map! { |i| URI.decode(i.force_encoding('ASCII-8BIT').force_encoding('UTF-8')).split('=') }]
    end

    def credit_card_deauthorize_by_merchant_order_no(params = {})
      param_required! params, [:Amt, :MerchantOrderNo]

      post_params = {
        IndexType: 1
      }.merge!(params)

      credit_card_deauthorize post_params
    end

    def credit_card_deauthorize_by_trade_no(params = {})
      param_required! params, [:Amt, :TradeNo]

      post_params = {
        IndexType: 2
      }.merge!(params)

      credit_card_deauthorize post_params
    end

    def credit_card_collect_refund(params = {})
      param_required! params, [:Amt, :IndexType, :CloseType]

      raise MissingOption, %(One of the following param is required: MerchantOrderNo, TradeNo) if params[:MerchantOrderNo].nil? && params[:TradeNo].nil?

      post_params = {
        RespondType: 'String',
        Version: '1.0',
        TimeStamp: Time.now.to_i
      }.merge!(params)

      res = request :credit_card_collect_refund, post_params
      Hash[res.body.split('&').map! { |i| URI.decode(i.force_encoding('ASCII-8BIT').force_encoding('UTF-8')).split('=') }]
    end

    def credit_card_collect_refund_by_merchant_order_no(params = {})
      param_required! params, [:Amt, :MerchantOrderNo, :CloseType]

      post_params = {
        IndexType: 1
      }.merge!(params)

      credit_card_collect_refund post_params
    end

    def credit_card_collect_refund_by_trade_no(params = {})
      param_required! params, [:Amt, :TradeNo, :CloseType]

      post_params = {
        IndexType: 1
      }.merge!(params)

      credit_card_collect_refund post_params
    end

    def generate_credit_card_period_params(params = {})
      param_required! params, [:MerchantOrderNo, :ProdDesc, :PeriodAmt, :PeriodAmtMode, :PeriodType, :PeriodPoint, :PeriodStartType, :PeriodTimes]

      generate_params(:credit_card_period, {
        RespondType: 'String',
        TimeStamp: Time.now.to_i,
        Version: '1.0'
      }.merge!(params))
    end

    private

    def request(type, params = {})
      case type
      when :query_trade_info
        api_url = TRANSACTION_API_ENDPOINTS[@options[:mode]]
      when :credit_card_deauthorize
        api_url = CREDITCARD_DEAUTHORIZE_API_ENDPOINTS[@options[:mode]]
      when :credit_card_collect_refund
        api_url = CREDITCARD_COLLECT_REFUND_API_ENDPOINTS[@options[:mode]]
      end

      if NEED_CHECK_VALUE_APIS.include?(type)
        post_params = generate_params(type, params)
      else
        post_params = {
          MerchantID_: @options[:merchant_id],
          PostData_: encode_post_data(URI.encode(params.map { |key, value| "#{key}=#{value}" }.join('&')))
        }
      end

      Net::HTTP.post_form URI(api_url), post_params
    end
  end
end
