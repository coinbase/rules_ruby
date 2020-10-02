load(
    "//ruby/private/tools:deps.bzl",
    _transitive_deps = "transitive_deps",
)
load(
    "//ruby/private:providers.bzl",
    "RubyGem",
    "RubyLibrary",
)
load("//ruby/private/gem:dest_path.bzl", _dest_path = "dest_path")

def _get_transitive_srcs(srcs, deps):
    return depset(
        srcs,
        transitive = [dep[RubyLibrary].transitive_ruby_srcs for dep in deps],
    )

def _rb_gemspec_impl(ctx):
    gemspec = ctx.actions.declare_file("{}.gemspec".format(ctx.attr.gem_name))
    metadata_file = ctx.actions.declare_file("{}_metadata".format(ctx.attr.gem_name))

    _ruby_files = []
    file_deps = _get_transitive_srcs([], ctx.attr.deps).to_list()

    strip_package = ctx.attr.strip_package

    for f in file_deps:
        # For some files the src_path and dest_path will be the same, but
        # for others the src_path will be in bazel-out while the dest_path
        # will be from the workspace root.
        dest_path = _dest_path(f, strip_package)
        _ruby_files.append({
            "src_path": f.path,
            "dest_path": dest_path,
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
            gem_runtime_dependencies = ctx.attr.gem_runtime_dependencies,
            do_strip = (strip_package != ""),
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
    "gem_runtime_dependencies": attr.string_list(
        mandatory = False,
        allow_empty = True,
        default = [],
    ),
    "require_paths": attr.string_list(),
    "_gemspec_template": attr.label(
        allow_single_file = True,
        default = ":gemspec_template.tpl",
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
        default = ":gemspec_builder.rb",
        allow_single_file = True,
    ),
    "strip_package": attr.string(
            default = "",
            doc = "strip this dir prefix from file paths added to the gem, such as package_name()",
    ),
}

rb_gemspec = rule(
    implementation = _rb_gemspec_impl,
    attrs = _ATTRS,
    provides = [DefaultInfo, RubyGem],
)
