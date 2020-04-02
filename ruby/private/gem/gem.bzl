load("//ruby/private:providers.bzl", "RubyGem")

# Runs gem with arbitrary arguments
# eg: run_gem(runtime_ctx, ["install" "foo"])
def _rb_build_gem_impl(ctx):
    args = [
        ctx.file._gem_runner.path,
        "build",
        ctx.attr.gemspec[RubyGem].gemspec.path,
        # Last arg should always be output path
        ctx.outputs.gem.path,
    ]

    _inputs = [ctx.file._gem_runner]
    for dep in ctx.attr.deps:
        _inputs.extend(dep.files.to_list())

    # the gem_runner does not support sandboxing because
    # gem build cannot handle symlinks and needs to write
    # the files as actual files.
    ctx.actions.run(
        inputs = _inputs,
        executable = ctx.attr.ruby_interpreter.files_to_run.executable,
        arguments = args,
        outputs = [ctx.outputs.gem],
        execution_requirements = {
            "no-sandbox": "1",
        },
    )

_ATTRS = {
    "ruby_sdk": attr.string(
        default = "@org_ruby_lang_ruby_toolchain",
    ),
    "ruby_interpreter": attr.label(
        default = "@org_ruby_lang_ruby_toolchain//:ruby_bin",
        allow_files = True,
        executable = True,
        cfg = "host",
    ),
    "_gem_runner": attr.label(
        default = Label("@coinbase_rules_ruby//ruby/private/gem:gem_runner.rb"),
        allow_single_file = True,
    ),
    "gemspec": attr.label(
        # allow_files = True,
    ),
    "gem_name": attr.string(
    ),
    "deps": attr.label_list(
        allow_files = True,
    ),
    "version": attr.string(),
}

rb_build_gem = rule(
    implementation = _rb_build_gem_impl,
    attrs = _ATTRS,
    outputs = {
        "gem": "%{gem_name}-%{version}.gem",
    },
)
