# JobGrapher

While looking through multiple gems and applications, I needed a little tool to help me.

This gem outputs a [PlantUML](https://plantuml.com) diagram of class/location's that perform a job.  The parser and logic were built while exploring [Samvera](https://samvera.org)'s ActiveJob implementations.

This gem requires [Ripgrep](https://github.com/BurntSushi/ripgrep).

## General Notes

While this is specific to application jobs, it would not take much to generalize this for class/module references.  In other words show the relationships between constants.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add job_grapher

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install job_grapher

## Usage

This gem came about as a thought experiment.  Here's the command line:

```shell
job_grapher ~/path/to/repo ~/path/to/other-repo
```

### From Ruby

At present, the command-line only allows you to specify directories.  However, you can call the underlying Ruby class and provide additional parameters.

```ruby
require "job_grapher"

JobGrapher.plantuml_for(
  dirs: [
    "~/git/hyrax",
    "~/git/bulkrax",
    "~/git/hyku",
    "~/git/newspaper_works/"
  ],
  filter: ->(job) do
    job.include?("Permission") || job.include?("Ingest")
  end
)
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jeremyf/job_grapher.
