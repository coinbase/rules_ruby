package(default_visibility = ["//:__subpackages__"])
load(
    "//ruby:defs.bzl",
    "rb_library",
)

rb_library(
    name = "example_gem",
    srcs = ["example_gem.rb"],
    deps = ["//ruby/tests/gemspec/lib/foo:default_library"],
)
