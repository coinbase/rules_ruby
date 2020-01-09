load("//ruby/private:constants.bzl", "RULES_RUBY_WORKSPACE_NAME")
load("//ruby/private:providers.bzl", "RubyRuntimeContext")

DEFAULT_BUNDLER_VERSION = "2.1.2"
BUNDLE_BIN_PATH = "bin"
BUNDLE_PATH = "lib"
BUNDLE_BINARY = "bundler/exe/bundler"

SCRIPT_INSTALL_GEM = "download_gem.rb"
SCRIPT_BUILD_FILE_GENERATOR = "create_bundle_build_file.rb"

# Runs bundler with arbitrary arguments
# eg: run_bundler(runtime_ctx, [ "lock", " --gemfile", "Gemfile.rails5" ])
def run_bundler(runtime_ctx, bundler_arguments):
    #print("BUNDLE RUN", bundler_arguments)

    # Now we are running bundle install
    args = [
        runtime_ctx.interpreter,  # ruby
        "--enable=gems",  # bundler must run with rubygems enabled
        "-I",
        ".",
        "-I",  # Used to tell Ruby where to load the library scripts
        BUNDLE_PATH,  # Add vendor/bundle to the list of resolvers
        BUNDLE_BINARY,  # our binary
    ] + bundler_arguments

    # print("Bundler Command:\n\n", args)

    return runtime_ctx.ctx.execute(
        args,
        quiet = False,
        environment = runtime_ctx.environment,
    )

#
# Sets local bundler config values by calling
#
# $ bundle config --local | --global config-option config-value
#
# @config_category can be either 'local' or 'global'
def set_bundler_config(runtime_ctx, config_category = "local"):
    # Bundler is deprecating various flags in favor of the configuration.
    # HOWEVER — for reasons I can't explain, Bazel runs "bundle install" *prior*
    # to setting these flags. So the flags are then useless until we can force the
    # order and ensure that Bazel first downloads Bundler, then sets config, then
    # runs bundle install. Until then, it's a wild west out here.
    #
    # Set local configuration options for bundler
    bundler_config = {
        "deployment": "true",
        "standalone": "true",
        "frozen": "true",
        "without": "development,test",
        "path": BUNDLE_PATH,
        "jobs": "20",
    }

    for option, value in bundler_config.items():
        args = ["config", "--%s" % (config_category), option, value]

        result = run_bundler(runtime_ctx, args)
        if result.return_code:
            message = "Failed to set bundle config {} to {}: {}".format(
                option,
                value,
                result.stderr,
            )
            fail(message)

    # The new way to generate binstubs is via the binstubs command, not config option.
    return run_bundler(runtime_ctx, ["binstubs", "--path", BUNDLE_BIN_PATH])

# This function is called "pure_ruby" because it downloads and unpacks the gem
# file into a given folder, which for gems without C-extensions is the same
# as install. To support gems that have C-extensions, the Ruby file install_gem.rb
# will need to be modified to use Gem::Installer.at(path).install(gem) API.
def install_pure_ruby_gem(runtime_ctx, gem_name, gem_version, folder):
    # USAGE: ./install_bundler.rb gem-name gem-version destination-folder
    args = [
        runtime_ctx.interpreter,
        SCRIPT_INSTALL_GEM,
        gem_name,
        gem_version,
        folder,
    ]
    result = runtime_ctx.ctx.execute(args, environment = runtime_ctx.environment)
    if result.return_code:
        message = "Failed to install gem {}-{} to {} with {}: {}".format(
            gem_name,
            gem_version,
            folder,
            runtime_ctx.interpreter,
            result.stderr,
        )
        fail(message)

def install_bundler(runtime_ctx, bundler_version):
    return install_pure_ruby_gem(
        runtime_ctx,
        "bundler",
        bundler_version,
        "bundler",
    )

def bundle_install(runtime_ctx):
    result = run_bundler(
        runtime_ctx,
        [
            "install",  #  bundle install
            "--standalone",  # Makes a bundle that can work without depending on Rubygems or Bundler at runtime.
            "--binstubs={}".format(BUNDLE_BIN_PATH),  # Creates a directory and place any executables from the gem there.
            "--path={}".format(BUNDLE_PATH),  # The location to install the specified gems to.
        ],
    )

    if result.return_code:
        fail("bundle install failed: %s%s" % (result.stdout, result.stderr))

def generate_bundle_build_file(runtime_ctx):
    # Create the BUILD file to expose the gems to the WORKSPACE
    # USAGE: ./create_bundle_build_file.rb BUILD.bazel Gemfile.lock repo-name [excludes-json] workspace-name
    args = [
        runtime_ctx.interpreter,  # ruby interpreter
        "--enable=gems",  # prevent the addition of gem installation directories to the default load path
        "-I",  # -I lib (adds this folder to $LOAD_PATH where ruby searches for things)
        "bundler/lib",
        SCRIPT_BUILD_FILE_GENERATOR,  # The template used to created bundle file
        "BUILD.bazel",  # Bazel build file (can be empty)
        "Gemfile.lock",  # Gemfile.lock where we list all direct and transitive dependencies
        runtime_ctx.ctx.name,  # Name of the target
        repr(runtime_ctx.ctx.attr.excludes),
        RULES_RUBY_WORKSPACE_NAME,
    ]

    result = runtime_ctx.ctx.execute(args, quiet = False)
    if result.return_code:
        fail("build file generation failed: %s%s" % (result.stdout, result.stderr))

def _rb_bundle_impl(ctx):
    ctx.symlink(ctx.attr.gemfile, "Gemfile")
    ctx.symlink(ctx.attr.gemfile_lock, "Gemfile.lock")
    ctx.symlink(ctx.attr._create_bundle_build_file, SCRIPT_BUILD_FILE_GENERATOR)
    ctx.symlink(ctx.attr._install_bundler, SCRIPT_INSTALL_GEM)

    bundler_version = ctx.attr.bundler_version

    # Setup this provider that we pass around between functions for convenience
    runtime_ctx = RubyRuntimeContext(
        ctx = ctx,
        interpreter = ctx.path(ctx.attr.ruby_interpreter),
        environment = {"RUBYOPT": "--enable-gems"},
    )

    # 1. Install the right version of the Bundler Gem
    install_bundler(runtime_ctx, bundler_version)

    # Create label for the Bundler executable
    bundler = Label("//:" + BUNDLE_BINARY)

    # 2. Set Bundler config in the .bundle/config file
    set_bundler_config(runtime_ctx)

    # 3. Run bundle install
    bundle_install(runtime_ctx)

    # 4. Generate the BUILD file for the bundle
    generate_bundle_build_file(runtime_ctx)

rb_bundle = repository_rule(
    implementation = _rb_bundle_impl,
    attrs = {
        "ruby_sdk": attr.string(
            default = "@org_ruby_lang_ruby_toolchain",
        ),
        "ruby_interpreter": attr.label(
            default = "@org_ruby_lang_ruby_toolchain//:ruby",
        ),
        "gemfile": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "gemfile_lock": attr.label(
            allow_single_file = True,
        ),
        "version": attr.string(
            mandatory = False,
        ),
        "bundler_version": attr.string(
            default = DEFAULT_BUNDLER_VERSION,
        ),
        "gemspec": attr.label(
            allow_single_file = True,
        ),
        "excludes": attr.string_list_dict(
            doc = "List of glob patterns per gem to be excluded from the library",
        ),
        "_install_bundler": attr.label(
            default = "%s//ruby/private/bundle:%s" % (
                RULES_RUBY_WORKSPACE_NAME,
                SCRIPT_INSTALL_GEM,
            ),
            allow_single_file = True,
        ),
        "_create_bundle_build_file": attr.label(
            default = "%s//ruby/private/bundle:%s" % (
                RULES_RUBY_WORKSPACE_NAME,
                SCRIPT_BUILD_FILE_GENERATOR,
            ),
            doc = "Creates the BUILD file",
            allow_single_file = True,
        ),
    },
)
