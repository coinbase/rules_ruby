# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name          = 'require_gem'
  s.summary       = 'require_gem'
  s.authors       = ['Coinbase']
  s.version       = '0.1.0'
  s.licenses      = []
  s.files         = ['ruby/tests/gemspec/lib/foo/bar.rb', 'ruby/tests/gemspec/lib/example_gem.rb']
  s.require_paths = ['ruby/tests/gemspec/lib/foo']
end
