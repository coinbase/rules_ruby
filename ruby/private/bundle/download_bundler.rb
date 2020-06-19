#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rubygems/gem_runner'

def main
  # Gem install bundler
  # TODO: DO NOT MERGE UNTIL YOU HAVE ADDED THE BUNDLER VERSION LOGIC
  args = [
    'install',
    '--install-dir',
    'bundler',
    'bundler'
  ]
  Gem::GemRunner.new.run args
end

main if $PROGRAM_NAME == __FILE__
