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
      test: 'https://cinv.ezpay.com/API/invoice_issue',
      production: 'https://inv.ezpay.com/API/invoice_issue'
    }.freeze
    INVOICE_INVALID_API_ENDPOINTS = {
      test: 'https://cinv.ezpay.com/API/invoice_invalid',
      production: 'https://inv.ezpay.com/API/invoice_invalid'
    }.freeze
    ALLOWANCE_ISSUE_API_ENDPOINTS = {
      test: 'https://cinv.ezpay.com/API/allowance_issue',
      production: 'https://inv.ezpay.com/API/allowance_issue'
    }.freeze
    INVOICE_SEARCH_API_ENDPOINTS = {
      test: 'https://cinv.ezpay.com/API/invoice_search',
      production: 'https://inv.ezpay.com/API/invoice_search'
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
