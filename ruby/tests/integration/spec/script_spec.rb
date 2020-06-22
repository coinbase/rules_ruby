# frozen_string_literal: true

require 'spec_helper'
require 'script'

describe 'oss_rand' do
  it 'generates a String' do
    expect(oss_rand).to be_a_kind_of String
  end
end

describe 'gem loading' do
  it 'only loads expected gems and their deps' do
    expect(Gem.loaded_specs.length).to eq(12)
    expect(Gem.loaded_specs.keys).to contain_exactly(
      'awesome_print',
      'diff-lcs',
      'ipaddr',
      'openssl',
      'rspec',
      'rspec-core',
      'rspec-expectations',
      'rspec-its',
      'rspec-mocks',
      'rspec-support',
      'stringio',
      'strscan'
    )
  end

  it 'errors when requiring gems that are in Gemfile, but not included in lib rule' do
    expect { Gem::Specification.find_by_name('rubocop') }.to raise_error(Gem::MissingSpecError)
  end

  # bundler gets installed separately so we need to ensure it isn't accidentally being included
  it 'errors when requiring bundler because it is not in the lib rule' do
    expect { Gem::Specification.find_by_name('bundler') }.to raise_error(Gem::MissingSpecError)
  end
end

describe 'validate rb_env' do
  it 'sets GEM_HOME correctly' do
    expect(ENV['GEM_HOME']).to end_with('rb_default_test.runfiles/integration_test_bundle/lib/ruby/2.6.0')
  end

  it 'sets GEM_PATH correctly' do
    gem_paths = ENV['GEM_PATH'].split(':')
    expect(gem_paths.length).to eq(2)
    expect(gem_paths[0]).to end_with('rb_default_test.runfiles/integration_test_bundle/lib/ruby/2.6.0')
    expect(gem_paths[1]).to end_with('rb_default_test.runfiles/integration_test_bundle/bundler')
  end
end
