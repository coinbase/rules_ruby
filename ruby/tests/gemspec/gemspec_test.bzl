load("@wspace_bazel_skylib//rules:diff_test.bzl", "diff_test")
load("@wspace_bazel_skylib//rules:select_file.bzl", "select_file")
load("//ruby:defs.bzl", "rb_gem", "rb_gemspec")

def gemspec_test(name, **kwargs):
    if not name.endswith("_test"):
        fail("Gemspec test must end with '_test'")

    base_name = name.replace("_test", "")
    gem_name = "{}_gem".format(base_name)
    select_name = "select_{}_spec".format(base_name)
    gemspec_name = "{}.gemspec".format(gem_name)
    expected_gemsepc = ":expected/{}".format(gemspec_name)

    rb_gemspec(
        name = gem_name,
        **kwargs
    )

    select_file(
        name = select_name,
        srcs = gem_name,
        subpath = gemspec_name,
    )

    diff_test(
        name = name,
        file1 = select_name,
        file2 = expected_gemsepc,
    )
