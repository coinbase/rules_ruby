#!/usr/bin/env ruby
# frozen_string_literal: true

TEMPLATE = <<~MAIN_TEMPLATE
  load(
    "{workspace_name}//ruby:defs.bzl",
    "rb_library",
  )

  package(default_visibility = ["//visibility:public"])

  rb_library(
    name = "bundler_setup",
    srcs = ["lib/bundler/setup.rb"],
    visibility = ["//visibility:private"],
  )

  rb_library(
    name = "bundler",
    srcs = glob(
      include = [
        "bundler/**/*",
      ],
    ),
    rubyopt = ["{bundler_setup}"],
  )

  # PULL EACH GEM INDIVIDUALLY
MAIN_TEMPLATE

GEM_TEMPLATE = <<~GEM_TEMPLATE
  rb_library(
    name = "{name}",
    srcs = glob(
      include = [
        "lib/ruby/{ruby_version}/gems/{name}-{version}/**/*",
        "bin/*"
      ],
      exclude = {exclude},
    ),
    deps = {deps},
    includes = ["lib/ruby/{ruby_version}/gems/{name}-{version}/lib"],
    rubyopt = ["{bundler_setup}"],
  )
GEM_TEMPLATE

ALL_GEMS = <<~ALL_GEMS
  rb_library(
    name = "gems",
    srcs = glob(
      {gems_lib_files},
    ),
    includes = {gems_lib_paths},
    rubyopt = ["{bundler_setup}"],
  )
ALL_GEMS

GEM_LIB_PATH = ->(ruby_version, gem_name, gem_version) do
  "lib/ruby/#{ruby_version}/gems/#{gem_name}-#{gem_version}/lib"
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
              :ruby_version

  def initialize(workspace_name:,
                 repo_name:,
                 build_file: 'BUILD.bazel',
                 gemfile_lock: 'Gemfile.lock',
                 excludes: nil)
    @workspace_name = workspace_name
    @repo_name      = repo_name
    @build_file     = build_file
    @gemfile_lock   = gemfile_lock
    @excludes       = excludes
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
                        .gsub('{bundler_setup}', bundler_setup_require)

    # strip bundler version so we can process this file
    remove_bundler_version!
    # Append to the end specific gem libraries and dependencies
    bundle        = Bundler::LockfileParser.new(Bundler.read_file(gemfile_lock))
    gem_lib_paths = []
    bundle.specs.each { |spec| register_gem(spec, template_out, gem_lib_paths) }

    template_out.puts ALL_GEMS
                        .gsub('{gems_lib_files}', gem_lib_paths.map { |p| "#{p}/**/*.rb" }.to_s)
                        .gsub('{gems_lib_paths}', gem_lib_paths.to_s)
                        .gsub('{bundler_setup}', bundler_setup_require)

    ::File.open(build_file, 'w') { |f| f.puts template_out.string }
  end

  private

  def bundler_setup_require
    @bundler_setup_require ||= "-r#{runfiles_path('lib/bundler/setup.rb')}"
  end

  def runfiles_path(path)
    "${RUNFILES_DIR}/#{repo_name}/#{path}"
  end

  # This method scans the contents of the Gemfile.lock and if it finds BUNDLED WITH
  # it strips that line + the line below it, so that any version of bundler would work.
  def remove_bundler_version!
    contents = File.read(gemfile_lock)
    return unless contents =~ /BUNDLED WITH/

    temp_gemfile_lock = "#{gemfile_lock}.no-bundle-version"
    system %(sed -n '/BUNDLED WITH/q;p' "#{gemfile_lock}" > #{temp_gemfile_lock})
    ::FileUtils.rm_f(gemfile_lock) if File.symlink?(gemfile_lock) # it's just a symlink
    ::FileUtils.move(temp_gemfile_lock, gemfile_lock, force: true)
  end

  def register_gem(spec, template_out, gem_lib_paths)
    gem_lib_paths << GEM_LIB_PATH[ruby_version, spec.name, spec.version]
    deps = spec.dependencies.map { |d| ":#{d.name}" }
    deps += [':bundler_setup']

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
                        .gsub('{bundler_setup}', bundler_setup_require)
  end
end

# ruby ./create_bundle_build_file.rb "BUILD.bazel" "Gemfile.lock" "repo_name" "[]" "wsp_name"
if $0 == __FILE__
  if ARGV.length != 5
    warn("USAGE: #{$0} BUILD.bazel Gemfile.lock repo-name [excludes-json] workspace-name")
    exit(1)
  end

  build_file, gemfile_lock, repo_name, excludes, workspace_name, * = *ARGV

  BundleBuildFileGenerator.new(build_file:     build_file,
                               gemfile_lock:   gemfile_lock,
                               repo_name:      repo_name,
                               excludes:       JSON.parse(excludes),
                               workspace_name: workspace_name)
    .generate!

end
