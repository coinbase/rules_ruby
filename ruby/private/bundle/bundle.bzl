load("//ruby/private:constants.bzl", "RULES_RUBY_WORKSPACE_NAME")
load("//ruby/private:providers.bzl", "RubyRuntimeContext")

DEFAULT_BUNDLER_VERSION = "2.1.2"
BUNDLE_BIN_PATH = "bin"
BUNDLE_PATH = "lib"

SCRIPT_INSTALL_BUNDLER = "download_bundler.rb"
SCRIPT_ACTIVATE_GEMS = "activate_gems.rb"
SCRIPT_BUILD_FILE_GENERATOR = "create_bundle_build_file.rb"

# Runs bundler with arbitrary arguments
# eg: run_bundler(runtime_ctx, [ "lock", " --gemfile", "Gemfile.rails5" ])
def run_bundler(runtime_ctx, bundler_arguments):
    # Now we are running bundle install
    args = [
        runtime_ctx.interpreter,  # ruby
        "-I",
        ".",
        "-I",  # Used to tell Ruby where to load the library scripts
        BUNDLE_PATH,  # Add vendor/bundle to the list of resolvers
        "bundler/gems/bundler-{}/exe/bundle".format(runtime_ctx.bundler_version),  # our binary
    ] + bundler_arguments

    kwargs = {}

    if "BUNDLER_TIMEOUT" in runtime_ctx.ctx.os.environ:
        timeout_in_secs = runtime_ctx.ctx.os.environ["BUNDLER_TIMEOUT"]
        if timeout_in_secs.isdigit():
            kwargs["timeout"] = int(timeout_in_secs)
        else:
            fail("'%s' is invalid value for BUNDLER_TIMEOUT. Must be an integer." % (timeout_in_secs))

    return runtime_ctx.ctx.execute(
        args,
        quiet = False,
        # Need to run this command with GEM_HOME set so tgat the bin stubs can load the correct bundler
        environment = {"GEM_HOME": "bundler", "GEM_PATH": "bundler"},
        **kwargs
    )

def install_bundler(runtime_ctx):
    args = [
        runtime_ctx.interpreter,
        SCRIPT_INSTALL_BUNDLER,
        runtime_ctx.bundler_version,
    ]
    result = runtime_ctx.ctx.execute(args, environment = runtime_ctx.environment, quiet = False)
    if result.return_code:
        fail("Error installing bundler: {} {}".format(result.stdout, result.stderr))

def bundle_install(runtime_ctx):
    bundler_args = [
        "install",  #  bundle install
        "--standalone",  # Makes a bundle that can work without depending on Rubygems or Bundler at runtime.
        "--binstubs={}".format(BUNDLE_BIN_PATH),  # Creates a directory and place any executables from the gem there.
        "--path={}".format(BUNDLE_PATH),  # The location to install the specified gems to.
        "--jobs=10",  # run a few jobs to ensure no gem install is blocking another
    ]

    if runtime_ctx.full_index:
        bundler_args.append("--full-index")
    result = run_bundler(runtime_ctx, bundler_args)

    if result.return_code:
        fail("bundle install failed: %s%s" % (result.stdout, result.stderr))

def generate_bundle_build_file(runtime_ctx):
    # Create the BUILD file to expose the gems to the WORKSPACE
    # USAGE: ./create_bundle_build_file.rb BUILD.bazel Gemfile.lock repo-name [excludes-json] workspace-name
    args = [
        runtime_ctx.interpreter,  # ruby interpreter
        SCRIPT_BUILD_FILE_GENERATOR,  # The template used to created bundle file
        "BUILD.bazel",  # Bazel build file (can be empty)
        "Gemfile.lock",  # Gemfile.lock where we list all direct and transitive dependencies
        runtime_ctx.ctx.name,  # Name of the target
        repr(runtime_ctx.ctx.attr.excludes),
        RULES_RUBY_WORKSPACE_NAME,
        runtime_ctx.bundler_version,
    ]

    result = runtime_ctx.ctx.execute(
        args,
        # The build file generation script requires bundler so we add this to make
        # the correct version of bundler available
        environment = {"GEM_HOME": "bundler", "GEM_PATH": "bundler"},
        quiet = False,
    )
    if result.return_code:
        fail("build file generation failed: %s%s" % (result.stdout, result.stderr))

def _rb_bundle_impl(ctx):
    ctx.symlink(ctx.attr.gemfile, "Gemfile")
    ctx.symlink(ctx.attr.gemfile_lock, "Gemfile.lock")
    ctx.symlink(ctx.attr._create_bundle_build_file, SCRIPT_BUILD_FILE_GENERATOR)
    ctx.symlink(ctx.attr._install_bundler, SCRIPT_INSTALL_BUNDLER)
    ctx.symlink(ctx.attr._activate_gems, SCRIPT_ACTIVATE_GEMS)

    # Setup this provider that we pass around between functions for convenience
    runtime_ctx = RubyRuntimeContext(
        ctx = ctx,
        interpreter = ctx.path(ctx.attr.ruby_interpreter),
        environment = {"RUBYOPT": "--enable-gems"},
        bundler_version = ctx.attr.bundler_version,
    )

    # 1. Install the right version of the Bundler Gem
    install_bundler(runtime_ctx)

    # Create label for the Bundler executable
    bundler = Label("//:bundler/gems/bundler-{}/exe/bundle".format(runtime_ctx.bundler_version))

    # Run bundle install
    bundle_install(runtime_ctx)

    # Generate the BUILD file for the bundle
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
        "excludes": attr.string_list_dict(
            doc = "List of glob patterns per gem to be excluded from the library",
        ),
        "full_index": attr.bool(
            default = False,
            doc = "Use --full-index for bundle install",
        ),
        "_install_bundler": attr.label(
            default = "%s//ruby/private/bundle:%s" % (
                RULES_RUBY_WORKSPACE_NAME,
                SCRIPT_INSTALL_BUNDLER,
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
        "_activate_gems": attr.label(
            default = "%s//ruby/private/bundle:%s" % (
                RULES_RUBY_WORKSPACE_NAME,
                SCRIPT_ACTIVATE_GEMS,
            ),
            allow_single_file = True,
        ),
    },
)
