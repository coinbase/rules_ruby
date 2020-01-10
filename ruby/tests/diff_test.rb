#!/usr/bin/ruby -w
# frozen_string_literal: true

require 'optparse'

def parse_flags(args)
  stdin = IO::NULL
  golden = nil
  parser = OptionParser.new do |opts|
    opts.on('--stdin=PATH') do |v|
      stdin = v
    end

    opts.on('--golden=PATH') do |v|
      golden = v
    end
  end
  args = parser.parse(args)

  [args, stdin, golden]
end

def main(args)
  args, stdin, golden = parse_flags(args)
  args << { in: stdin }
  stdout = IO.popen(args, &:read)

  IO.popen(['diff', '-B', '-c', golden, '-'], 'w') { |io| io << stdout }
  exit $CHILD_STATUS.exitstatus
end

main(ARGV) if $PROGRAM_NAME == __FILE__
