#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rubygems/gem_runner'

def main
  # This should always be set by bundle.bzl
  bundler_version = ARGV[0]

  args = [
    'install',
    '--install-dir',
    'bundler',
    "bundler:#{bundler_version}"
  ]

  begin
    Gem::GemRunner.new.run args
  rescue Gem::SystemExitException => e
    exit e.exit_code
  end
end

main if $PROGRAM_NAME == __FILE__
