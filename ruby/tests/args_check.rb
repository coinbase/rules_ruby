# frozen_string_literal: true

# Checks if args to rb_binary rules propagate to the actual
# ruby processes

expected = %w[foo bar baz]

raise "Expected ARGV to be #{expected}; got #{ARGV}" unless ARGV == expected
