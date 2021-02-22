#!/usr/bin/env ruby

if __FILE__ == $0
  curr_file = File.symlink?(__FILE__) ? File.readlink(__FILE__) : File.absolute_path(__FILE__)
  curr_dir = File.dirname(curr_file)
  exec("#{curr_dir}/{launcher_name}", {main}, *ARGV)
end
