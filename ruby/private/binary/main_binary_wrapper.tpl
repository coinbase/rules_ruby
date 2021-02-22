#!/usr/bin/env ruby

if __FILE__ == $0
  curr_dir = File.dirname(File.absolute_path($0))
  exec("#{curr_dir}/{launcher_name}", {main}, *ARGV)
end
