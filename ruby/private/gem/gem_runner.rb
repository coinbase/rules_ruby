# frozen_string_literal: true

require 'rubygems'
require 'rubygems/gem_runner'
require 'rubygems/exceptions'

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

  Gem::GemRunner.new.run args
rescue Gem::SystemExitException => e
  exit e.exit_code
end
