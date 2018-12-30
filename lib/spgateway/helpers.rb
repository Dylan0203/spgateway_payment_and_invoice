module Spgateway
  module Helpers
    def verify_check_code(params = {})
      stringified_keys = params.stringify_keys
      check_code = stringified_keys.delete('CheckCode')
      make_check_code(stringified_keys) == check_code
    end

    def encode_post_data(data)
      cipher = OpenSSL::Cipher::AES256.new(:CBC)
      cipher.encrypt
      cipher.padding = 0
      cipher.key = @options[:hash_key]
      cipher.iv = @options[:hash_iv]
      data = add_padding(data)
      encrypted = cipher.update(data) + cipher.final
      encrypted.unpack('H*').first
    end

    def make_check_value(type, params = {})
      case type
      when :mpg
        check_value_fields = %i[Amt MerchantID MerchantOrderNo TimeStamp Version]
        padded = "HashKey=#{@options[:hash_key]}&%s&HashIV=#{@options[:hash_iv]}"
      when :query_trade_info
        check_value_fields = %i[Amt MerchantID MerchantOrderNo]
        padded = "IV=#{@options[:hash_iv]}&%s&Key=#{@options[:hash_key]}"
      when :credit_card_period
        check_value_fields = %i[MerchantID MerchantOrderNo PeriodAmt PeriodType TimeStamp]
        padded = "HashKey=#{@options[:hash_key]}&%s&HashIV=#{@options[:hash_iv]}"
      else
        raise UnsupportedType, 'Unsupported API type.'
      end

      param_required! params, check_value_fields

      raw = params.select { |key, _value| key.to_s.match(/^(#{check_value_fields.join('|')})$/) }
                  .sort_by { |k, _v| k.downcase }.map! { |k, v| "#{k}=#{v}" }.join('&')

      padded = padded % raw

      Digest::SHA256.hexdigest(padded).upcase!
    end

    private

    def option_required!(*option_names)
      option_names.each do |option_name|
        raise MissingOption, %(option "#{option_name}" is required.) if @options[option_name].nil?
      end
    end

    def param_required!(params, param_names)
      param_names.each do |param_name|
        raise MissingParameter, %(param "#{param_name}" is required.) if params[param_name].nil?
      end
    end

    def make_check_code(params = {})
      raw = params.select { |key, _value| key.to_s.match(/^(Amt|MerchantID|MerchantOrderNo|TradeNo)$/) }
                  .sort_by { |k, _v| k.downcase }.map! { |k, v| "#{k}=#{v}" }.join('&')
      padded = "HashIV=#{@options[:hash_iv]}&#{raw}&HashKey=#{@options[:hash_key]}"
      Digest::SHA256.hexdigest(padded).upcase!
    end

    def generate_params(type, overwrite_params = {})
      result = overwrite_params.clone
      result[:MerchantID] = @options[:merchant_id]
      result[:CheckValue] = make_check_value(type, result)
      result
    end

    def add_padding(text, size = 32)
      len = text.length
      pad = size - (len % size)
      text += (pad.chr * pad)
    end
  end
end