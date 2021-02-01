load(
    "//ruby/private/gem:gemspec.bzl",
    _rb_gemspec = "rb_gemspec",
)
load(
    "//ruby/private/gem:gem.bzl",
    _rb_build_gem = "rb_build_gem",
)

def rb_gem(name, version, gem_name, **kwargs):
    _gemspec_name = name + "_gemspec"
    deps = kwargs.get("deps", [])
    source_date_epoch = kwargs.pop("source_date_epoch", None)
    srcs = kwargs.pop("srcs", [])
    strip_paths = kwargs.pop("strip_paths", [])
    verbose = kwargs.pop("verbose", False)

    _rb_gemspec(
        name = _gemspec_name,
        gem_name = gem_name,
        version = version,
        strip_paths = strip_paths,
        **kwargs
    )

    _rb_build_gem(
        name = name,
        gem_name = gem_name,
        gemspec = _gemspec_name,
        version = version,
        deps = srcs + deps,
        visibility = ["//visibility:public"],
        source_date_epoch = source_date_epoch,
        strip_paths = strip_paths,
        verbose = verbose,
    )
