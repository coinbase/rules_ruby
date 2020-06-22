# frozen_string_literal: true

require 'openssl'
require 'awesome_print'

require 'lib/foo'

def oss_rand
  OpenSSL::BN.rand(512).to_s
end

def output
  ap Foo.aha + ' ' + oss_rand
end

output
