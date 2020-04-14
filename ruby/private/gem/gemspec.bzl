load(
    "//ruby/private/tools:deps.bzl",
    _transitive_deps = "transitive_deps",
)
load(
    "//ruby/private:providers.bzl",
    "RubyGem",
    "RubyLibrary",
)

def _get_transitive_srcs(srcs, deps):
    return depset(
        srcs,
        transitive = [dep[RubyLibrary].transitive_ruby_srcs for dep in deps],
    )

def _rb_gem_impl(ctx):
    gemspec = ctx.actions.declare_file("{}.gemspec".format(ctx.attr.gem_name))
    metadata_file = ctx.actions.declare_file("{}_metadata".format(ctx.attr.gem_name))

    _ruby_files = []
    file_deps = _get_transitive_srcs([], ctx.attr.deps).to_list()
    for f in file_deps:
      # For some files the src_path and dest_path will be the same, but
      # for othrs the src_path will be in bazel)out while the dest_path
      # will be from the workspace root.
        _ruby_files.append({
            "src_path": f.path,
            "dest_path": f.short_path,
        })

    ctx.actions.write(
        output = metadata_file,
        content = struct(
            name = ctx.attr.gem_name,
            raw_srcs = _ruby_files,
            authors = ctx.attr.authors,
            version = ctx.attr.version,
            licenses = ctx.attr.licenses,
            require_paths = ctx.attr.require_paths,
        ).to_json(),
    )

    ctx.actions.run(
        inputs = [
            ctx.file._gemspec_template,
            ctx.file._gemspec_builder,
            metadata_file,
        ] + file_deps,
        executable = ctx.attr.ruby_interpreter.files_to_run.executable,
        arguments = [
            ctx.file._gemspec_builder.path,
            "--output",
            gemspec.path,
            "--metadata",
            metadata_file.path,
            "--template",
            ctx.file._gemspec_template.path,
        ],
        outputs = [gemspec],
        execution_requirements = {
            "no-sandbox": "1",
        },
    )

    return [
        DefaultInfo(files = _get_transitive_srcs([gemspec], ctx.attr.deps)),
        RubyGem(
            ctx = ctx,
            version = ctx.attr.version,
            gemspec = gemspec,
        ),
    ]

_ATTRS = {
    "version": attr.string(
        default = "0.0.1",
    ),
    "authors": attr.string_list(),
    "licenses": attr.string_list(),
    "deps": attr.label_list(
        allow_files = True,
    ),
    "data": attr.label_list(
        allow_files = True,
    ),
    "gem_name": attr.string(),
    "srcs": attr.label_list(
        allow_files = True,
        default = [],
    ),
    "gem_deps": attr.label_list(
        allow_files = True,
    ),
    "require_paths": attr.string_list(),
    "_gemspec_template": attr.label(
        allow_single_file = True,
        default = "gemspec_template.tpl",
    ),
    "ruby_sdk": attr.string(
        default = "@org_ruby_lang_ruby_toolchain",
    ),
    "ruby_interpreter": attr.label(
        default = "@org_ruby_lang_ruby_toolchain//:ruby_bin",
        allow_files = True,
        executable = True,
        cfg = "host",
    ),
    "_gemspec_builder": attr.label(
        default = Label("@coinbase_rules_ruby//ruby/private/gem:gemspec_builder.rb"),
        allow_single_file = True,
    ),
}

rb_gemspec = rule(
    implementation = _rb_gem_impl,
    attrs = _ATTRS,
    provides = [DefaultInfo, RubyGem],
)
