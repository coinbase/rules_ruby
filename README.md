<!-- TOC depthFrom:1 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 -->

* [Usage](#usage)
  * [WORKSPACE File](#workspace-file)
  * [BUILD.bazel files](#buildbazel-files)
* [Rules](#rules)
  * [rb_library](#rb_library)
  * [rb_binary](#rb_binary)
  * [rb_test](#rb_test)
  * [ruby_bundle](#ruby_bundle)
* [What's coming next](#whats-coming-next)
* [Contributing](#contributing)
  * [Setup](#setup)
    * [OSX Setup Script](#os-setup-script)
      * [Issues During Setup](#issues-during-setup)
  * [Developing Rules](#developing-rules)
  * [Running Tests](#running-tests)
  * [Linter](#linter)
* [Copyright](#copyright)

<!-- /TOC -->

### Build Status

| Build | Status |
|---------:	|---------------------------------------------------------------------------------------------------------------------------------------------------	|
| CircleCI Master: 	| [![CircleCI](https://circleci.com/gh/coinbase/rules_ruby.svg?style=svg)](https://circleci.com/gh/coinbase/rules_ruby) 	|


# Rules Ruby

Ruby rules for [Bazel](https://bazel.build).

** Current Status:** *Work in progress.*

Note: we have a short guide on [Building your first Ruby Project](https://github.com/coinbase/rules_ruby/wiki/Build-your-ruby-project) on the Wiki. We encourage you to check it out.

## Usage

### `WORKSPACE` File

Add `rules_ruby_dependencies` and `ruby_register_toolchains` into your `WORKSPACE` file.

```python
# To get the latest, grab the 'master' branch.

git_repository(
    name = "coinbase_rules_ruby",
    remote = "https://github.com/coinbase/rules_ruby.git",
    branch = "master",
)

load(
    "@coinbase_rules_ruby//ruby:deps.bzl",
    "ruby_register_toolchains",
    "rules_ruby_dependencies",
)

rules_ruby_dependencies()

ruby_register_toolchains()
```

Next, add any external Gem dependencies you may have via `ruby_bundle` command.
The name of the bundle becomes a reference to this particular Gemfile.lock.

Install external gems that can be later referenced as `@<bundle-name>//:<gem-name>`,
and the executables from each gem can be accessed as `@<bundle-name//:bin/<gem-binary-name>`
for instance, `@bundle//:bin/rubocop`.

You can install more than one bundle per WORKSPACE, but that's not recommended.

```python
ruby_bundle(
  name = "bundle",
  gemfile = ":Gemfile",
  gemfile_lock = ":Gemfile.lock",
  bundler_version = "2.1.2",
)

ruby_bundle(
  name = "bundle_app_shopping",
  gemfile = "//apps/shopping:Gemfile",
  gemfile_lock = "//apps/shopping:Gemfile.lock",
  bundler_version = "2.1.2",
)
```

### `BUILD.bazel` files

Add `rb_library`, `rb_binary` or `rb_test` into your `BUILD.bazel` files.

```python
load(
    "@coinbase_rules_ruby//ruby:defs.bzl",
    "rb_binary",
    "rb_library",
    "rb_test",
    "ruby_rspec",
)

rb_library(
    name = "foo",
    srcs = glob(["lib/**/*.rb"]),
    includes = ["lib"],
    deps = [
      "@bundle//:activesupport",
      "@bundle//:awesome_print",
      "@bundle//:rubocop",
    ]
)

rb_binary(
    name = "bar",
    srcs = ["bin/bar"],
    deps = [":foo"],
)

rb_test(
    name = "foo-test",
    srcs = ["test/foo_test.rb"],
    deps = [":foo"],
)

ruby_rspec(
    name = "foo-spec",
    specs = glob(["spec/**/*.rb"]),
    rspec_args = { "--format": "progress" },
    deps = [":foo"]
}

```

## Rules

The following diagram attempts to capture the implementation behind `rb_library` that depends on the result of `bundle install`, and a `rb_binary` that depends on both:

![Ruby Rules](docs/img/rules_ruby.png)


### `rb_library`

<pre>
rb_library(name, deps, srcs, data, compatible_with, deprecation, distribs, features, licenses, restricted_to, tags, testonly, toolchains, visibility)
</pre>

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <code>Name, required</code>
        <p>A unique name for this rule.</p>
      </td>
    </tr>
    <tr>
      <td><code>srcs</code></td>
      <td>
        <code>List of Labels, optional</code>
        <p>
          List of <code>.rb</code> files.
        </p>
        <p>At least <code>srcs</code> or <code>deps</code> must be present</p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <code>List of labels, optional</code>
        <p>
          List of targets that are required by the <code>srcs</code> Ruby
          files.
        </p>
        <p>At least <code>srcs</code> or <code>deps</code> must be present</p>
      </td>
    </tr>
    <tr>
      <td><code>includes</code></td>
      <td>
        <code>List of strings, optional</code>
        <p>
          List of paths to be added to <code>$LOAD_PATH</code> at runtime.
          The paths must be relative to the the workspace which this rule belongs to.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>rubyopt</code></td>
      <td>
        <code>List of strings, optional</code>
        <p>
          List of options to be passed to the Ruby interpreter at runtime.
        </p>
        <p>
          NOTE: <code>-I</code> option should usually go to <code>includes</code> attribute.
        </p>
      </td>
    </tr>
  </tbody>
  <tbody>
    <tr>
      <td colspan="2">And other <a href="https://docs.bazel.build/versions/master/be/common-definitions.html#common-attributes">common attributes</a></td>
    </tr>
  </tbody>
</table>

### `rb_binary`

<pre>
rb_binary(name, deps, srcs, data, main, compatible_with, deprecation, distribs, features, licenses, restricted_to, tags, testonly, toolchains, visibility, args, output_licenses)
</pre>

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <code>Name, required</code>
        <p>A unique name for this rule.</p>
      </td>
    </tr>
    <tr>
      <td><code>srcs</code></td>
      <td>
        <code>List of Labels, required</code>
        <p>
          List of <code>.rb</code> files.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <code>List of labels, optional</code>
        <p>
          List of targets that are required by the <code>srcs</code> Ruby
          files.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>main</code></td>
      <td>
        <code>Label, optional</code>
        <p>The entrypoint file. It must be also in <code>srcs</code>.</p>
        <p>If not specified, <code><var>$(NAME)</var>.rb</code> where <code>$(NAME)</code> is the <code>name</code> of this rule.</p>
      </td>
    </tr>
    <tr>
      <td><code>includes</code></td>
      <td>
        <code>List of strings, optional</code>
        <p>
          List of paths to be added to <code>$LOAD_PATH</code> at runtime.
          The paths must be relative to the the workspace which this rule belongs to.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>rubyopt</code></td>
      <td>
        <code>List of strings, optional</code>
        <p>
          List of options to be passed to the Ruby interpreter at runtime.
        </p>
        <p>
          NOTE: <code>-I</code> option should usually go to <code>includes</code> attribute.
        </p>
      </td>
    </tr>
  </tbody>
  <tbody>
    <tr>
      <td colspan="2">And other <a href="https://docs.bazel.build/versions/master/be/common-definitions.html#common-attributes">common attributes</a></td>
    </tr>
  </tbody>
</table>

### `rb_test`

<pre>
rb_test(name, deps, srcs, data, main, compatible_with, deprecation, distribs, features, licenses, restricted_to, tags, testonly, toolchains, visibility, args, size, timeout, flaky, local, shard_count)
</pre>

<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <code>Name, required</code>
        <p>A unique name for this rule.</p>
      </td>
    </tr>
    <tr>
      <td><code>srcs</code></td>
      <td>
        <code>List of Labels, required</code>
        <p>
          List of <code>.rb</code> files.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>deps</code></td>
      <td>
        <code>List of labels, optional</code>
        <p>
          List of targets that are required by the <code>srcs</code> Ruby
          files.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>main</code></td>
      <td>
        <code>Label, optional</code>
        <p>The entrypoint file. It must be also in <code>srcs</code>.</p>
        <p>If not specified, <code><var>$(NAME)</var>.rb</code> where <code>$(NAME)</code> is the <code>name</code> of this rule.</p>
      </td>
    </tr>
    <tr>
      <td><code>includes</code></td>
      <td>
        <code>List of strings, optional</code>
        <p>
          List of paths to be added to <code>$LOAD_PATH</code> at runtime.
          The paths must be relative to the the workspace which this rule belongs to.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>rubyopt</code></td>
      <td>
        <code>List of strings, optional</code>
        <p>
          List of options to be passed to the Ruby interpreter at runtime.
        </p>
        <p>
          NOTE: <code>-I</code> option should usually go to <code>includes</code> attribute.
        </p>
      </td>
    </tr>
  </tbody>
  <tbody>
    <tr>
      <td colspan="2">And other <a href="https://docs.bazel.build/versions/master/be/common-definitions.html#common-attributes">common attributes</a></td>
    </tr>
  </tbody>
</table>

### `ruby_bundle`

Installs gems with Bundler, and make them available as a `rb_library`.

Example: `WORKSPACE`:

```python
git_repository(
    name = "coinbase_rules_ruby",
    remote = "https://github.com/coinbase/rules_ruby.git",
    tag = "v0.1.0",
)

load(
    "@coinbase_rules_ruby//ruby:deps.bzl",
    "ruby_register_toolchains",
    "rules_ruby_dependencies",
)

rules_ruby_dependencies()

ruby_register_toolchains()

load("@coinbase_rules_ruby//ruby:defs.bzl", "ruby_bundle")

ruby_bundle(
    name = "gems",
    gemfile = "//:Gemfile",
    gemfile_lock = "//:Gemfile.lock",
)
```

Example: `lib/BUILD.bazel`:

```python
rb_library(
    name = "foo",
    srcs = ["foo.rb"],
    deps = ["@gems//:all"],
)
```

Or declare many gems in your `Gemfile`, and only use some of them in each ruby library:

```python
rb_binary(
    name = "rubocop",
    srcs = [":foo", ".rubocop.yml"],
    args = ["-P", "-D", "-c" ".rubocop.yml"],
    main = "@gems//:bin/rubocop",
    deps = ["@gems//:rubocop"],
)
```

<pre>
ruby_bundle(name, gemfile, gemfile_lock, bundler_version = "2.1.2")
</pre>
<table class="table table-condensed table-bordered table-params">
  <colgroup>
    <col class="col-param" />
    <col class="param-description" />
  </colgroup>
  <thead>
    <tr>
      <th colspan="2">Attributes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>name</code></td>
      <td>
        <code>Name, required</code>
        <p>A unique name for this rule.</p>
      </td>
    </tr>
    <tr>
      <td><code>gemfile</code></td>
      <td>
        <code>Label, required</code>
        <p>
          The <code>Gemfile</code> which Bundler runs with.
        </p>
      </td>
    </tr>
    <tr>
      <td><code>gemfile_lock</code></td>
      <td>
        <code>Label, required</code>
          <p>The <code>Gemfile.lock</code> which Bundler runs with.</p>
          <p>NOTE: This rule never updates the <code>Gemfile.lock</code>. It is your responsibility to generate/update <code>Gemfile.lock</code></p>
      </td>
    </tr>
    <tr>
      <td><code>bundler_version</code></td>
      <td>
        <code>String, optional</code>
          <p>The Version of Bundler to use. Defaults to 2.1.2.</p>
          <p>NOTE: This rule never updates the <code>Gemfile.lock</code>. It is your responsibility to generate/update <code>Gemfile.lock</code></p>
      </td>
    </tr>
  </tbody>
</table>

## What's coming next

1. Building native extensions in gems with Bazel
2. Using a specified version of Ruby.
3. Building and releasing your gems with Bazel

## Contributing

We welcome contributions to RulesRuby.

You may notice that there is more than one Bazel WORKSPACE inside this repo. There is one in `examples/simple_script` for instance, because
we use this example to validate and test the rules. So be mindful whether your current directory contains `WORKSPACE` file or not.

### Setup

#### OSX Setup Script

You will need Homebrew installed prior to running the script.

After that, cd into the top level folder and run the setup script in your Terminal:

```bash
❯ bin/setup-darwin
```
##### Issues During Setup

**Please report any errors as Issues on Github.**

### Developing Rules

Besides making yourself familiar with the existing code, and [Bazel documentation on writing rules](https://docs.bazel.build/versions/master/skylark/concepts.html), you might want to follow this order:

  1. Setup dev tools as described in the [setup](#Setup) section.
  3. hack, hack, hack...
  4. Make sure all tests pass — you can run individual Bazel test commands from the inside.

   * `bazel test //...`
   * `cd examples/simple_script && bazel test //...`

  4. Open a pull request in Github, and please be as verbose as possible in your description.

In general, it's always a good idea to ask questions first — you can do so by creating an issue.

### Running Tests

After running setup, and since this is a bazel repo you can use Bazel commands:

```bazel
bazel build //...:all
bazel query //...:all
bazel test //...:all
```

But to run tests inside each sub-WORKSPACE, you will need to repeat that in each sub-folder.

### Linter

We are using RuboCop for ruby and Buildifier for Bazel. Both can be run using bazel:

```bash
bazel run //:buildifier
```

## Copyright

© 2018-2019 Yuki Yugui Sonoda & BazelRuby Authors

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

<http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
