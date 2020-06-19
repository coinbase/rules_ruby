load(":constants.bzl", "RUBY_ATTRS", "TOOLCHAIN_TYPE_NAME")
load(
    "//ruby/private/tools:deps.bzl",
    _transitive_deps = "transitive_deps",
)

def _to_manifest_path(ctx, file):
    if file.short_path.startswith("../"):
        return file.short_path[3:]
    else:
        return ("%s/%s" % (ctx.workspace_name, file.short_path))

def _get_gem_path(incpaths):
    """
    incpaths is a list of `<bundle_name>/lib/ruby/<version>/gems/<gemname>-<gemversion>/lib`
    The gem_path is `<bundle_name>/lib/ruby/<version>` so we can go from an incpath to the
    gem_path pretty easily without much additional work.
    """
    if len(incpaths) == 0:
        return ""
    incpath = incpaths[0]
    return incpath.rsplit("/", 3)[0]


def _get_bundle_path(gem_path):
    """
    This is mainly a way to get the bundle name so we can add the path to bundler to the gem
    path env var. The bundle path is just: `<bundle_name>/bundler`
    """
    if not gem_path:
        return ""
    return gem_path.split("/")[0] + "/bundler"

# Having this function allows us to override otherwise frozen attributes
# such as main, srcs and deps. We use this in rb_rspec_test rule by
# adding rspec as a main, and sources, and rspec gem as a dependency.
#
# There could be similar situations in the future where we might want
# to create a rule (eg, rubocop) that does exactly the same.
def rb_binary_macro(ctx, main, srcs):
    sdk = ctx.toolchains[TOOLCHAIN_TYPE_NAME].ruby_runtime
    interpreter = sdk.interpreter[DefaultInfo].files_to_run.executable

    if not main:
        expected_name = "%s.rb" % ctx.attr.name
        for f in srcs:
            if f.label.name == expected_name:
                main = f.files.to_list()[0]
                break
    if not main:
        fail(
            ("main must be present unless the name of the rule matches to " +
             "one of the srcs"),
            "main",
        )

    executable = ctx.actions.declare_file(ctx.attr.name)

    deps = _transitive_deps(
        ctx,
        extra_files = [executable],
        extra_deps = ctx.attr._misc_deps,
    )

    gem_path = _get_gem_path(deps.incpaths.to_list())
    bundle_path = _get_bundle_path(gem_path)

    gems_to_pristine = ctx.attr.force_gem_pristine

    rubyopt = reversed(deps.rubyopt.to_list())

    ctx.actions.expand_template(
        template = ctx.file._wrapper_template,
        output = executable,
        substitutions = {
            "{loadpaths}": repr(deps.incpaths.to_list()),
            "{rubyopt}": repr(rubyopt),
            "{main}": repr(_to_manifest_path(ctx, main)),
            "{interpreter}": _to_manifest_path(ctx, interpreter),
            "{gem_path}": gem_path,
            "{bundle_path}": bundle_path,
            "{should_gem_pristine}": str(len(gems_to_pristine) > 0).lower(),
            "{gems_to_pristine}": " ".join(gems_to_pristine),
            "{run_under}": ctx.attr.run_under,
        },
    )

    info = DefaultInfo(
        executable = executable,
        runfiles = deps.default_files.merge(deps.data_files),
    )

    return [info]

def rb_binary_impl(ctx):
    return rb_binary_macro(
        ctx,
        ctx.file.main,
        ctx.attr.srcs,
    )

rb_binary = rule(
    implementation = rb_binary_impl,
    attrs = RUBY_ATTRS,
    executable = True,
    toolchains = [TOOLCHAIN_TYPE_NAME],
)

rb_test = rule(
    implementation = rb_binary_impl,
    attrs = RUBY_ATTRS,
    test = True,
    toolchains = [TOOLCHAIN_TYPE_NAME],
)
