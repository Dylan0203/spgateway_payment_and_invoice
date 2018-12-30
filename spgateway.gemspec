# coding: utf-8
# frozen_string_literal: true
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'spgateway/version'

Gem::Specification.new do |spec|
  spec.name          = 'spgateway_payment_and_invoice_client'
  spec.version       = Spgateway::VERSION
  spec.authors       = ['FunnyQ']
  spec.email         = ['funnyq@gmail.com']

  spec.summary       = 'Spgateway(payment gateway @ Taiwan) and ezPay Invoice API wrapper'
  spec.description   = 'Spgateway(payment gateway @ Taiwan) and ezPay Invoice API wrapper'
  spec.homepage      = 'https://github.com/oracle-design/spgateway_payment_and_invoice'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'json'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'rake', '~> 12.3.1'
end
