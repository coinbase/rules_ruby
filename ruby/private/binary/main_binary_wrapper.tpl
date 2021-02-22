#!/usr/bin/env ruby

if __FILE__ == $0
  curr_file = File.absolute_path(__FILE__)
  curr_dir = File.dirname(curr_file)

  if File.exists?("#{curr_dir}/{launcher_name}")
    exec("#{curr_dir}/{launcher_name}", {main}, *ARGV)
  end

  if File.symlink?(curr_file) &&  %r!(.*\.runfiles)/.*!o =~ File.readlink(curr_file)
    runfiles_dir = File.dirname(File.readlink(curr_file))
    exec("#{runfiles_dir}/{launcher_name}", {main}, *ARGV)
  end
end
