# frozen_string_literal: true

require 'rubygems'
require 'rubygems/gem_runner'
require 'rubygems/exceptions'
require 'rubygems/version'

require 'fileutils'

required_version = Gem::Requirement.new '>= 1.8.7'

abort "Expected Ruby Version #{required_version}, is #{Gem.ruby_version}" unless required_version.satisfied_by? Gem.ruby_version

# Dereferences a file (converts it from a symlink to a real file Pinocchio)
def dereference!(file)
  return if !File.symlink?(file) || File.directory?(file)

  tmpname = '/tmp' + File.expand_path(file)
  FileUtils.mkdir_p(File.dirname(tmpname))
  warn "copying #{file} to #{tmpname}"
  FileUtils.cp(file, tmpname)
  warn "moving #{tmpname} to #{file}"
  FileUtils.mv(tmpname, file)
end

args = ARGV.clone

# Gem builder does not like symlinks .. so make real files from any symlinks ..
Dir.glob('./**/*').grep_v(%r{^\./bazel}).grep_v(%r{^\./external}) do |f|
  dereference!(f)
end

begin
  args = args.map do |arg|
    if arg.include?('gemspec') && File.exist?(arg) # Jank hack -- gemspec file needs to be in same directory as the
      # source files ..
      FileUtils.copy(arg, File.basename(arg))
      File.basename(arg)
    else
      arg
    end
  end

  output_path = args.pop()
  post_build_copy = false
  if Gem.rubygems_version < Gem::Version.new('3.0.0')
    post_build_copy = true
  else
    args = args + ["--output", output_path]
  end

  Gem::GemRunner.new.run args

  if post_build_copy == true
    # Move output to correct location
    FileUtils.cp(File.basename(output_path), output_path)
  end
rescue Gem::SystemExitException => e
  warn "bye"
  exit e.exit_code
end
