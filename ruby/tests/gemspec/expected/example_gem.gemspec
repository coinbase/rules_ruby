Gem::Specification.new do |s|
  s.name                     = "example_gem"
  s.summary                  = "example_gem"
  s.authors                  = ["Coinbase"]
  s.version                  = "0.1.0"
  s.licenses                 = []
  s.files                    = ["ruby/tests/gemspec/lib/foo/bar.rb", "ruby/tests/gemspec/lib/example_gem.rb"]
  s.require_paths            = ["ruby/tests/gemspec/lib"]

  spec.add_runtime_dependency 'example1', '~> 1.1', '>= 1.1.4'
  spec.add_runtime_dependency 'example2', '~> 1.0'
end
