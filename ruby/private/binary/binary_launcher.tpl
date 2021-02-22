#!/usr/bin/env ruby

# Ruby-port of the Bazel's wrapper script for Python

# Copyright 2017 The Bazel Authors. All rights reserved.
# Copyright 2019 BazelRuby Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'rbconfig'

def find_runfiles
  stub_dirname = File.dirname(File.absolute_path($0))
  stub_filename = "#{stub_dirname}/{rule_name}"
  runfiles = "#{stub_filename}.runfiles"
  loop do
    case
    when File.directory?(runfiles)
      return runfiles
    when %r!(.*\.runfiles)/.*!o =~ stub_filename
      return $1
    when File.symlink?(stub_filename)
      target = File.readlink(stub_filename)
      stub_filename = File.absolute_path(target, File.dirname(stub_filename))
    else
      break
    end
  end
  raise "Cannot find .runfiles directory for #{$0}"
end

def create_loadpath_entries(custom, runfiles)
  [runfiles] + custom.map {|path| File.join(runfiles, path) }
end

def get_repository_imports(runfiles)
  Dir.children(runfiles).map {|d|
    File.join(runfiles, d)
  }.select {|d|
    File.directory? d
  }
end

# Finds the runfiles manifest or the runfiles directory.
def runfiles_envvar(runfiles)
  # If this binary is the data-dependency of another one, the other sets
  # RUNFILES_MANIFEST_FILE or RUNFILES_DIR for our sake.
  manifest = ENV['RUNFILES_MANIFEST_FILE']
  if manifest
    return ['RUNFILES_MANIFEST_FILE', manifest]
  end

  dir = ENV['RUNFILES_DIR']
  if dir
    return ['RUNFILES_DIR', dir]
  end

  # Look for the runfiles "output" manifest, argv[0] + ".runfiles_manifest"
  manifest = runfiles + '_manifest'
  if File.exists?(manifest)
    return ['RUNFILES_MANIFEST_FILE', manifest]
  end

  # Look for the runfiles "input" manifest, argv[0] + ".runfiles/MANIFEST"
  manifest = File.join(runfiles, 'MANIFEST')
  if File.exists?(manifest)
    return ['RUNFILES_DIR', manifest]
  end

  # If running in a sandbox and no environment variables are set, then
  # Look for the runfiles  next to the binary.
  if runfiles.end_with?('.runfiles') and File.directory?(runfiles)
    return ['RUNFILES_DIR', runfiles]
  end
end

def find_rb_binary
  File.join(
    RbConfig::CONFIG['bindir'],
    RbConfig::CONFIG['ruby_install_name'],
  )
end

def find_gem_binary
  File.join(
    RbConfig::CONFIG['bindir'],
    'gem',
  )
end

def setup_gem_path(runfiles)
  # Bundle path is based on gem_path so cannot be "" if gem_path exists
  if "{gem_path}" == ""
    return
  end
  full_bundle_path = File.join(runfiles, "{bundle_path}")
  full_gem_path = File.join(runfiles, "{gem_path}")

  # Caution: The str replace in bazel is also based on {var} so may conflict with
  # ruby str replacement.
  ENV["GEM_PATH"] = "#{full_gem_path}:#{full_bundle_path}"
  ENV["GEM_HOME"] = "#{full_gem_path}"
end

def main(args)
  raise "Must provide target to launch" if args.empty?

  runfiles = find_runfiles

  runfiles_envkey, runfiles_envvalue = runfiles_envvar(runfiles)
  ENV[runfiles_envkey] = runfiles_envvalue if runfiles_envkey

  custom_loadpaths = {loadpaths}
  loadpaths = create_loadpath_entries(custom_loadpaths, runfiles)
  loadpaths += get_repository_imports(runfiles)
  loadpaths += ENV['RUBYLIB'].split(':') if ENV.key?('RUBYLIB')
  ENV['RUBYLIB'] = loadpaths.join(':')

  setup_gem_path(runfiles)

  ruby_program = find_rb_binary

  main = args.shift
  main = File.join(runfiles, main)
  rubyopt = {rubyopt}.map do |opt|
    opt.gsub(/\${(.+?)}/o) do
      case $1
      when 'RUNFILES_DIR'
        runfiles
      else
        ENV[$1]
      end
    end
  end

  # This is a jank hack because some of our gems are having issues with how
  # they are being installed. Most gems are fine, but this fixes the ones that
  # aren't. Put it here instead of in the library because we want to fix the
  # underlying issue and then tear this out.
  if {should_gem_pristine} then
    gem_program = find_gem_binary
    puts "Running pristine on {gems_to_pristine}"
    system(gem_program + " pristine {gems_to_pristine}")
  end
  if "{run_under}" != "" then
    Dir.chdir("{run_under}")
  end

  exec(ruby_program, *rubyopt, main, *args)
end

if __FILE__ == $0
  main(ARGV)
end