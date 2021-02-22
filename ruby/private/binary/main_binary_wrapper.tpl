#!/usr/bin/env ruby

if __FILE__ == $0
  ##
  # Find the launcher
  ##

  curr_file = File.absolute_path(__FILE__)
  curr_dir = File.dirname(curr_file)

  # Check if it is in this directory
  if File.exists?("#{curr_dir}/{launcher_name}")
    exec("#{curr_dir}/{launcher_name}", {main}, *ARGV)
  end

  # Check if this file is a symlink to the runfiles directory... then it will be there
  if File.symlink?(curr_file) &&  %r!(.*\.runfiles)/.*!o =~ File.readlink(curr_file)
    runfiles_dir = File.dirname(File.readlink(curr_file))
    exec("#{runfiles_dir}/{launcher_name}", {main}, *ARGV)
  end

  raise "Could not find launcher file! This is likely an issue with rules_ruby"
end
