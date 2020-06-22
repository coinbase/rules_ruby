# frozen_string_literal: true
Gem::Specification.each do |spec|
  # Don't activate default gems because they may duplicate gems 
  # we already have (e.g. ruby bundler vs gem bundler)
  spec.activate unless spec.default_gem?
end
