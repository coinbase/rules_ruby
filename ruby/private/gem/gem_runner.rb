# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'optparse'
require 'rubygems'
require 'rubygems/gem_runner'
require 'rubygems/exceptions'
require 'rubygems/version'
require 'tmpdir'

def check_rubygems_version
  required_version = Gem::Requirement.new '>= 1.8.7'

  abort "Expected Ruby Version #{required_version}, is #{Gem.ruby_version}" unless required_version.satisfied_by? Gem.ruby_version
end

def parse_opts
  metadata_file = nil

  OptionParser.new do |opts|
    opts.on('--metadata [ARG]', 'Metadata file') do |v|
      metadata_file = v
    end
    opts.on('-h', '--help') do |_v|
      puts opts
      exit 0
    end
  end.parse!

  metadata_file
end

def copy_srcs(dir, srcs, verbose)
  # Sources need to be moved from their bazel_out locations
  # to the correct folder in the ruby gem.
  srcs.each do |src|
    src_path = src['src_path']
    dest_path = src['dest_path']
    tmpname = File.join(dir, File.dirname(dest_path))
    FileUtils.mkdir_p(tmpname)
    puts "copying #{src_path} to #{tmpname}" if verbose
    FileUtils.cp_r(src_path, tmpname)
    # Copying a directory will not dereference symlinks
    # in the directory. They need to be removed too.
    dereference_symlinks(tmpname, verbose) if File.directory?(tmpname)
  end
end

def dereference_symlinks(dir, verbose)
  Dir.glob("#{dir}/**/*") do |src|
    if File.symlink?(src)
      actual_src = File.realpath(src)
      puts "Dereferencing symlink at #{src} to #{actual_src}" if verbose
      FileUtils.cp_r(actual_src, src, remove_destination: true)
    end
  end
end

def copy_gemspec(dir, gemspec_path)
  # The gemspec file needs to be in the root of the build dir
  FileUtils.cp(gemspec_path, dir)
end

def do_build(dir, gemspec_path, output_path)
  args = [
    'build',
    File.join(dir, File.basename(gemspec_path))
  ]
  # Older versions of rubygems work better if the
  # cwd is the root of the gem dir.
  Dir.chdir(dir) do
    Gem::GemRunner.new.run args
  end
  FileUtils.cp(File.join(dir, File.basename(output_path)), output_path)
end

def build_gem(metadata)
  # We copy all related files to a tmpdir, build the entire gem in that tmpdir
  # and then copy the output gem into the correct bazel output location.
  verbose = metadata['verbose']
  Dir.mktmpdir do |dir|
    copy_srcs(dir, metadata['srcs'], verbose)
    copy_gemspec(dir, metadata['gemspec_path'])
    do_build(dir, metadata['gemspec_path'], metadata['output_path'])
  end
end

def main
  check_rubygems_version
  metadata_file = parse_opts
  m = File.read(metadata_file)
  metadata = JSON.parse(m)

  if metadata['source_date_epoch'] != ''
    # I think this will make it hermetic! YAY!
    ENV['SOURCE_DATE_EPOCH'] = metadata['source_date_epoch']
  end

  begin
    build_gem(metadata)
  rescue Gem::SystemExitException => e
    exit e.exit_code
  end
end

main if $PROGRAM_NAME == __FILE__
