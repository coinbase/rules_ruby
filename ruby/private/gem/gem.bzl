load("//ruby/private:providers.bzl", "RubyGem")

# Runs gem with arbitrary arguments
# eg: run_gem(runtime_ctx, ["install" "foo"])
def _rb_build_gem_impl(ctx):
    metadata_file = ctx.actions.declare_file("{}_build_metadata".format(ctx.attr.gem_name))
    gemspec = ctx.attr.gemspec[RubyGem].gemspec

    _inputs = [ctx.file._gem_runner, metadata_file, gemspec]
    _srcs = []
    for dep in ctx.attr.deps:
        file_deps = dep.files.to_list()
        _inputs.extend(file_deps)
        for f in file_deps:
            _srcs.append({
                "src_path": f.path,
                "dest_path": f.short_path,
            })

    ctx.actions.write(
        output = metadata_file,
        content = struct(
            srcs = _srcs,
            gemspec_path = gemspec.path,
            output_path = ctx.outputs.gem.path,
            source_date_epoch = ctx.attr.source_date_epoch,
        ).to_json(),
    )

    # the gem_runner does not support sandboxing because
    # gem build cannot handle symlinks and needs to write
    # the files as actual files.
    ctx.actions.run(
        inputs = _inputs,
        executable = ctx.attr.ruby_interpreter.files_to_run.executable,
        arguments = [
            ctx.file._gem_runner.path,
            "--metadata",
            metadata_file.path,
        ],
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
    "source_date_epoch": attr.string(
        doc = "Sets source_date_epoch env var which should make output gems hermetic",
    ),
}

rb_build_gem = rule(
    implementation = _rb_build_gem_impl,
    attrs = _ATTRS,
    outputs = {
        "gem": "%{gem_name}-%{version}.gem",
    },
)
