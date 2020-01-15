load("@coinbase_rules_ruby//ruby/private:binary.bzl", "rb_binary")

# This wraps an rb_binary in a script that is executed from the workspace folder
def rubocop(name, bin, deps):
    bin_name = name + "-ruby"
    rb_binary(
        name = bin_name,
        main = bin,
        deps = deps,
    )

    runner = "@coinbase_rules_ruby//ruby/private/rubocop:runner.sh.tpl"
    native.genrule(
        name = name,
        tools = [bin_name],
        srcs = [runner],
        executable = True,
        outs = [name + ".sh"],
        cmd = "sed \"s~{{BIN}}~$(location %s)~g\" $(location %s) > \"$@\"" % (bin_name, runner),
    )
