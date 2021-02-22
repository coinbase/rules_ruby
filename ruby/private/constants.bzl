load(":providers.bzl", "RubyLibrary")

RULES_RUBY_WORKSPACE_NAME = "@coinbase_rules_ruby"
TOOLCHAIN_TYPE_NAME = "%s//ruby:toolchain_type" % RULES_RUBY_WORKSPACE_NAME

DEFAULT_RSPEC_ARGS = {"--format": "documentation", "--force-color": None}
DEFAULT_RSPEC_GEMS = ["rspec", "rspec-its"]
DEFAULT_BUNDLE_NAME = "@bundle//"

RUBY_ATTRS = {
    "srcs": attr.label_list(
        allow_files = True,
    ),
    "deps": attr.label_list(
        providers = [RubyLibrary],
    ),
    "includes": attr.string_list(),
    "rubyopt": attr.string_list(),
    "data": attr.label_list(
        allow_files = True,
    ),
    "main": attr.label(
        allow_single_file = True,
    ),
    "force_gem_pristine": attr.string_list(
        doc = "Jank hack. Run gem pristine on some gems that don't handle symlinks well",
    ),
    "run_under": attr.string(
        doc = "Execute a directory change before running the binary.",
    ),
    "_wrapper_template": attr.label(
        allow_single_file = True,
        default = "//ruby/private/binary:main_binary_wrapper.tpl",
    ),
    "_launcher_template": attr.label(
        allow_single_file = True,
        default = "//ruby/private/binary:binary_launcher.tpl",
    ),
    "_misc_deps": attr.label_list(
        allow_files = True,
        default = ["@bazel_tools//tools/bash/runfiles"],
    ),
}

_RSPEC_ATTRS = {
    "bundle": attr.string(
        default = DEFAULT_BUNDLE_NAME,
        doc = "Name of the bundle where the rspec gem can be found, eg @bundle//",
    ),
    "rspec_args": attr.string_list(
        default = [],
        doc = "Arguments passed to rspec executable",
    ),
    "rspec_executable": attr.label(
        default = "%s:bin/rspec" % (DEFAULT_BUNDLE_NAME),
        allow_single_file = True,
        doc = "RSpec Executable Label",
    ),
}

RSPEC_ATTRS = {}

RSPEC_ATTRS.update(RUBY_ATTRS)
RSPEC_ATTRS.update(_RSPEC_ATTRS)
