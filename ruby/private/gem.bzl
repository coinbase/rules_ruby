load(
    "//ruby/private/gem:gemspec.bzl",
    _rb_gemspec = "rb_gemspec",
)
load(
    "//ruby/private/gem:gem.bzl",
    _rb_build_gem = "rb_build_gem",
)

def rb_gem(name, version, gem_name, srcs = [], **kwargs):
    _gemspec_name = name + "_gemspec"

    _rb_gemspec(
        name = _gemspec_name,
        gem_name = gem_name,
        version = version,
        **kwargs
    )

    _rb_build_gem(
        name = name,
        gem_name = gem_name,
        gemspec = _gemspec_name,
        version = version,
        deps = srcs + [_gemspec_name],
        visibility = ["//visibility:public"],
    )
