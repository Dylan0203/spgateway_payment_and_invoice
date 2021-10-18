require 'net/http'
require 'openssl'
require 'json'
require 'cgi'
require 'digest'
require 'spgateway/errors'
require 'spgateway/helpers'
require 'spgateway/core_ext/hash'

module Spgateway
  class InvoiceClient
    include Spgateway::Helpers

    INVOICE_ISSUE_API_ENDPOINTS = {
      test: 'https://cinv.ezpay.com.tw/API/invoice_issue',
      production: 'https://inv.ezpay.com.tw/API/invoice_issue'
    }.freeze
    INVOICE_INVALID_API_ENDPOINTS = {
      test: 'https://cinv.ezpay.com.tw/API/invoice_invalid',
      production: 'https://inv.ezpay.com.tw/API/invoice_invalid'
    }.freeze
    ALLOWANCE_ISSUE_API_ENDPOINTS = {
      test: 'https://cinv.ezpay.com.tw/API/allowance_issue',
      production: 'https://inv.ezpay.com.tw/API/allowance_issue'
    }.freeze
    INVOICE_SEARCH_API_ENDPOINTS = {
      test: 'https://cinv.ezpay.com.tw/API/invoice_search',
      production: 'https://inv.ezpay.com.tw/API/invoice_search'
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

    def invoice_issue(params = {})
      param_required! params, %i[
        MerchantOrderNo
        Status
        Category
        BuyerName
        PrintFlag
        TaxType
        TaxRate
        Amt
        TaxAmt
        TotalAmt
        ItemName
        ItemCount
        ItemUnit
        ItemPrice
        ItemAmt
      ]

      post_params = {
        RespondType: 'JSON',
        Version: '1.4',
        TimeStamp: Time.now.to_i
      }.merge!(params)

      post_params.delete_if { |_key, value| value.nil? }

      res = request :invoice_issue, post_params

      reslut_hash = JSON.parse(res.body)
      reslut_hash['Result'] = JSON.parse(reslut_hash['Result']) if reslut_hash['Result'].present?

      reslut_hash
    end

    def invoice_invalid(params = {})
      param_required! params, %i[
        InvoiceNumber
        InvalidReason
      ]

      post_params = {
        RespondType: 'JSON',
        Version: '1.0',
        TimeStamp: Time.now.to_i
      }.merge!(params)

      post_params.delete_if { |_key, value| value.nil? }

      res = request :invoice_invalid, post_params

      reslut_hash = JSON.parse(res.body)
      reslut_hash['Result'] = JSON.parse(reslut_hash['Result']) if reslut_hash['Result'].present?

      reslut_hash
    end

    def allowance_issue(params = {})
      param_required! params, %i[
        InvoiceNo
        MerchantOrderNo
        ItemName
        ItemCount
        ItemUnit
        ItemPrice
        ItemAmt
        ItemTaxAmt
        TotalAmt
        BuyerEmail
        Status
      ]

      post_params = {
        RespondType: 'JSON',
        Version: '1.3',
        TimeStamp: Time.now.to_i
      }.merge!(params)

      post_params.delete_if { |_key, value| value.nil? }

      res = request :allowance_issue, post_params

      reslut_hash = JSON.parse(res.body)
      reslut_hash['Result'] = JSON.parse(reslut_hash['Result']) if reslut_hash['Result'].present?

      reslut_hash
    end

    def invoice_search_by_merchant_order_no(params = {})
      param_required! params, %i[
        MerchantOrderNo
        TotalAmt
      ]

      post_params = {
        RespondType: 'JSON',
        Version: '1.3',
        TimeStamp: Time.now.to_i,
        SearchType: 1
      }.merge!(params)

      post_params.delete_if { |_key, value| value.nil? }

      res = request :invoice_search, post_params

      reslut_hash = JSON.parse(res.body)
      reslut_hash['Result'] = JSON.parse(reslut_hash['Result']) if reslut_hash['Result'].present?

      reslut_hash
    end

    def invoice_search_by_invoice_no(params = {}, offsite: false)
      param_required! params, %i[
        InvoiceNumber
        RandomNum
      ]

      post_params = {
        RespondType: 'JSON',
        Version: '1.3',
        TimeStamp: Time.now.to_i,
        SearchType: 0
      }.merge!(params)

      post_params.delete_if { |_key, value| value.nil? }

      # return only encoded postdata_ content if `offsite` was true
      return encode_post_data(URI.encode(post_params.map { |key, value| "#{key}=#{value}" }.join('&'))) if offsite

      res = request :invoice_search, post_params

      reslut_hash = JSON.parse(res.body)
      reslut_hash['Result'] = JSON.parse(reslut_hash['Result']) if reslut_hash['Result'].present?

      reslut_hash
    end

    private

    def request(type, params = {})
      case type
      when :invoice_issue
        api_url = INVOICE_ISSUE_API_ENDPOINTS[@options[:mode]]
      when :invoice_invalid
        api_url = INVOICE_INVALID_API_ENDPOINTS[@options[:mode]]
      when :allowance_issue
        api_url = ALLOWANCE_ISSUE_API_ENDPOINTS[@options[:mode]]
      when :invoice_search
        api_url = INVOICE_SEARCH_API_ENDPOINTS[@options[:mode]]
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
