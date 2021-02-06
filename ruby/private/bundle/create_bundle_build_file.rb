#!/usr/bin/env ruby
# frozen_string_literal: true

TEMPLATE = <<~MAIN_TEMPLATE
  load(
    "{workspace_name}//ruby:defs.bzl",
    "rb_library",
  )

  package(default_visibility = ["//visibility:public"])

  rb_library(
    name = "activate_gems",
    srcs = ["activate_gems.rb"],
    rubyopt = ["-r{runfiles_path}/activate_gems.rb"],
  )

  rb_library(
    name = "bundler",
    srcs = glob(
      include = [
        "bundler/**/*",
      ],
    ),
    includes = ["bundler/gems/bundler-{bundler_version}/lib"],
    rubyopt = ["-r{runfiles_path}/bundler/gems/bundler-{bundler_version}/lib/bundler.rb"],
  )

  # PULL EACH GEM INDIVIDUALLY
MAIN_TEMPLATE

# The build_complete file is only silence the 'extensions' are not built warnings. They are built.
# TODO: Replace the extensions ** with the platform (eg. x86_64-darwin-19)
GEM_TEMPLATE = <<~GEM_TEMPLATE
  rb_library(
    name = "{name}",
    srcs = glob(
      include = [
        "lib/ruby/{ruby_version}/gems/{name}-{version}*/**",
        "lib/ruby/{ruby_version}/specifications/{name}-{version}*.gemspec",
        "lib/ruby/{ruby_version}/cache/{name}-{version}*.gem",
        "lib/ruby/{ruby_version}/extensions/**/{ruby_version}/{name}-{version}/gem.build_complete",
        "bin/*"
      ],
      exclude = {exclude},
    ),
    deps = {deps},
    includes = ["lib/ruby/{ruby_version}/gems/{name}-{version}*/lib"],
  )
GEM_TEMPLATE

ALL_GEMS = <<~ALL_GEMS
  rb_library(
    name = "all_gems",
    srcs = glob(
      {gems_lib_files},
    ),
    includes = {gems_lib_paths},
  )
ALL_GEMS

GEM_LIB_PATH = lambda do |ruby_version, gem_name, gem_version|
  "lib/ruby/#{ruby_version}/gems/#{gem_name}-#{gem_version}*/lib"
end

require 'bundler'
require 'json'
require 'stringio'
require 'fileutils'
require 'tempfile'

class BundleBuildFileGenerator
  attr_reader :workspace_name,
              :repo_name,
              :build_file,
              :gemfile_lock,
              :excludes,
              :ruby_version,
              :bundler_version

  # rubocop:disable Metrics/ParameterLists
  def initialize(workspace_name:,
                 repo_name:,
                 bundler_version:,
                 build_file: 'BUILD.bazel',
                 gemfile_lock: 'Gemfile.lock',
                 excludes: nil)
    # rubocop:enable Metrics/ParameterLists
    @workspace_name = workspace_name
    @repo_name      = repo_name
    @build_file     = build_file
    @gemfile_lock   = gemfile_lock
    @excludes       = excludes
    @bundler_version = bundler_version
    # This attribute returns 0 as the third minor version number, which happens to be
    # what Ruby uses in the PATH to gems, eg. ruby 2.6.5 would have a folder called
    # ruby/2.6.0/gems for all minor versions of 2.6.*
    @ruby_version ||= (RUBY_VERSION.split('.')[0..1] << 0).join('.')
  end

  def generate!
    # when we append to a string many times, using StringIO is more efficient.
    template_out = StringIO.new

    # In Bazel we want to use __FILE__ because __dir__points to the actual sources, and we are
    # using symlinks here.
    #
    # rubocop:disable Style/ExpandPathArguments
    bin_folder = File.expand_path('../bin', __FILE__)
    binaries   = Dir.glob("#{bin_folder}/*").map do |binary|
      'bin/' + File.basename(binary) if File.executable?(binary)
    end
    # rubocop:enable Style/ExpandPathArguments

    template_out.puts TEMPLATE
      .gsub('{workspace_name}', workspace_name)
      .gsub('{repo_name}', repo_name)
      .gsub('{ruby_version}', ruby_version)
      .gsub('{binaries}', binaries.to_s)
      .gsub('{runfiles_path}', runfiles_path)
      .gsub('{bundler_version}', bundler_version)

    # strip bundler version so we can process this file
    remove_bundler_version!
    # Append to the end specific gem libraries and dependencies
    bundle        = Bundler::LockfileParser.new(Bundler.read_file(gemfile_lock))
    gem_lib_paths = []
    bundle.specs.each { |spec| register_gem(spec, template_out, gem_lib_paths) }

    template_out.puts ALL_GEMS
      .gsub('{gems_lib_files}', gem_lib_paths.map { |p| "#{p}/**/*.rb" }.to_s)
      .gsub('{gems_lib_paths}', gem_lib_paths.to_s)

    ::File.open(build_file, 'w') { |f| f.puts template_out.string }
  end

  private

  def runfiles_path
    "${RUNFILES_DIR}/#{repo_name}"
  end

  # This method scans the contents of the Gemfile.lock and if it finds BUNDLED WITH
  # it strips that line + the line below it, so that any version of bundler would work.
  def remove_bundler_version!
    contents = File.read(gemfile_lock)
    return unless contents =~ /BUNDLED WITH/

    temp_gemfile_lock = "#{gemfile_lock}.no-bundle-version"
    system %(sed -n '/BUNDLED WITH/q;p' "#{gemfile_lock}" > #{temp_gemfile_lock})
    if File.symlink?(gemfile_lock)
      ::FileUtils.rm_f(gemfile_lock) # it's just a symlink
    end
    ::FileUtils.move(temp_gemfile_lock, gemfile_lock, force: true)
  end

  def register_gem(spec, template_out, gem_lib_paths)
    gem_lib_paths << GEM_LIB_PATH[ruby_version, spec.name, spec.version]
    deps = spec.dependencies.map { |d| ":#{d.name}" }
    deps += [':activate_gems']

    exclude_array = excludes[spec.name] || []
    # We want to exclude files and folder with spaces in them
    exclude_array += ['**/* *.*', '**/* */*']

    template_out.puts GEM_TEMPLATE
      .gsub('{exclude}', exclude_array.to_s)
      .gsub('{name}', spec.name)
      .gsub('{version}', spec.version.to_s)
      .gsub('{deps}', deps.to_s)
      .gsub('{repo_name}', repo_name)
      .gsub('{ruby_version}', ruby_version)
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV.length != 6
    warn("USAGE: #{$PROGRAM_NAME} BUILD.bazel Gemfile.lock repo-name [excludes-json] workspace-name bundler-version")
    exit(1)
  end

  build_file, gemfile_lock, repo_name, excludes, workspace_name, bundler_version, * = *ARGV

  BundleBuildFileGenerator.new(build_file: build_file,
                               gemfile_lock: gemfile_lock,
                               repo_name: repo_name,
                               excludes: JSON.parse(excludes),
                               workspace_name: workspace_name,
                               bundler_version: bundler_version).generate!
end
