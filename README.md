# Bob The Builder

<p><img src="http://i.imgur.com/C7GBG.jpg" alt="Bob The Builder" title="Bob The Builder" align="right" style="padding-left: 10px"></p>

Bob The Builder is easy building and deploying applications.

## Installation

This can be achieved by easily using RubyGems

    $ gem install bob_the_builder

## What to do after installation

Once it is installed, you can configure any project by running its handy tool, called ```bobify```. It receives only one argument, and it is the location of the application's folder. If you are inside it, you just need to do:

    $ bobify .

This will generate a set of files, including a sample configuration YAML, and a couple sample scripts.

## Configuration

There should be a file called ```script/config.yml```. The main idea is that it contains a set of variables, that can be overridden per environment in different ways. The precedence order is:

1. Environment variables
2. Git configuration variables
3. YAML variable per environment
4. YAML global variable

Configuration variables defined in the YAML can call to another variable. There's a set of needed variables, here's the basic set:

```yaml
output: builds/my_output_v{{version}}_{{date}}.o
build_command: {{gcc}} {{input}} -o {{output}}
changes_regexp: "(Bug Fix|Improvement)"
gcc: /usr/bin/env gcc
input: src/input.c

github:
  username: my_github_username
  password: mypassword
  repo: ivanvc/bob

production:
  server: ivanvc@ec-12.compute1.amazonaws.com:/var/www/prod
  output: builds/output_prod.o
daily_build:
  server: ivanvc@ec-12.compute1.amazonaws.com:/var/www/daily
development:
  server: ivanvc@localhost:/Users/ivan/Sites/project
  output: builds/output.o
```

Here are a couple of things demonstrated, a variable can request another one using a [mustache](http://mustache.github.com/) similar syntax. There are two **Magic Variables** ```date``` and ```version```. The first one is the date when the command was called, ehmmm, Today... And version is the one read from the latest git tag.

Also, the variables inside each environment (development, daily_build and production) override the ones at the root.

If you specify GitHub's credentials, you will be able to upload the latest version to a GitHub repo, directly to the downloads section.

## Usage

In order to use Bob, you need to instantiate it, and do a build, deploy, version bump, etc. Here's a sample script:

```ruby
#!/usr/bin/env ruby
require 'rubygems'
require 'bob_the_builder'
include BobTheBuilder

# The first argument is the environment, matches the one from the config
# file. It also takes two optional arguments, the directory where the git
# repo is, defaults to '.'. The last one is the branch that bob should use
# defaults to 'master'.
builder = Bob.new('daily_build')

# We don't want the daily build if there are no changes, or if the source
# doesn't compiles.
if builder.changes_since_last_version? && builder.build
  # Bump the version 'patch', 'minor' or 'major'.
  builder.version_bump! ARGV[0]
  builder.build
  # Deploy to the server, and to GitHub.
  builder.deploy
  builder.deploy 'github'
end
```

This is the sample for a daily building script, it can be found in the script folder, and to call it, you just need to do:

    $ script/daily_build

And to do a simple deploy, here's a sample script:

```ruby
#!/usr/bin/env ruby
require 'rubygems'
require 'bob_the_builder'
include BobTheBuilder

# The first argument is the environment, matches the one from the config
# file. It also takes two optional arguments, the directory where the git
# repo is, defaults to '.'. The last one is the branch that bob should use
# defaults to 'master'.
builder = Bob.new(ARGV[0] || 'development')
builder.build
# The deploy option has an optional argument, where this deploy should be
# done. Defaults to 'server', but can be 'github'.
builder.deploy
```

In the latter, it initializes with the passed environment, i.e. ```script/deploy production``` will deploy and build using production settings.

As said before, any variable can be overridden using environment variables, let's say: ```OUTPUT=hello.o script/deploy development``` will use hello.o as the output instead of the stated in the configuration file.

## License

Copyright (c) 2011 Ivan Valdes (@ivanvc). See LICENSE.txt for further details.
