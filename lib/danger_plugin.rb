module Danger

  # Lint Swift files inside your projects.
  # This is done using the [SwiftLint](https://github.com/realm/SwiftLint) tool.
  # Results are passed out as a table in markdown.
  #
  # @example Specifying custom config file.
  #
  #          # Runs a linter with comma style disabled
  #          swiftlint.config_file = '.swiftlint.yml'
  #          swiftlint.lint_files
  #
  # @see  artsy/eigen
  # @tags swift
  #
  class DangerSwiftlint < Plugin

    # Allows you to specify a config file location for swiftlint.
    attr_accessor :config_file

    # Allows you to specify a directory from where swiftlint will be run.
    attr_accessor :directory

    # Allows you to specify to fail when errors exist.
    attr_accessor :fail_when_errors_exist

    # Lints Swift files. Will fail if `swiftlint` cannot be installed correctly.
    # Generates a `markdown` list of warnings for the prose in a corpus of .markdown and .md files.
    #
    # @param   [String] files
    #          A globbed string which should return the files that you want to lint, defaults to nil.
    #          if nil, modified and added files from the diff will be used.
    # @return  [void]
    #
    def lint_files
      # Installs SwiftLint if needed
      system "brew install swiftlint" unless swiftlint_installed?

      # Check that this is in the user's PATH after installing
      unless swiftlint_installed?
        fail "swiftlint is not in the user's PATH, or it failed to install"
        return
      end

      swiftlint_command = ""
      swiftlint_command += "cd #{directory} && " if directory
      swiftlint_command += "swiftlint lint --quiet --reporter json"
      swiftlint_command += " --config #{config_file}" if config_file

      require 'json'
      result_json = JSON.parse(`(#{swiftlint_command})`).flatten

      # Convert to swiftlint results
      warnings = result_json.select do |results|
        results['severity'] == 'Warning'
      end
      errors = result_json.select do |results|
        results['severity'] == 'Error'
      end

      if fail_when_errors_exist && errors.count > 0
        fail("SwiftLint found #{errors.count} error#{errors.count > 1 ? "s" : ""}.")
      end

      message = ''

      # We got some error reports back from swiftlint
      if warnings.count > 0 || errors.count > 0
        message = "### SwiftLint found issues\n\n"
      end

      message << parse_results(warnings, 'Warnings') unless warnings.empty?
      message << parse_results(errors, 'Errors') unless errors.empty?

      markdown message unless message.empty?
    end

    # Parses swiftlint invocation results into a string
    # which is formatted as a markdown table.
    #
    # @return  [String]
    #
    def parse_results (results, heading)
      message = "#### #{heading}\n\n"

      message << "File | Line | Reason |\n"
      message << "| --- | ----- | ----- |\n"

      results.each do |r|
        filename = r['file'].split('/').last
        line = r['line']
        reason = r['reason']

        message << "#{filename} | #{line} | #{reason} \n"
      end

      message
    end

    # Determine if swiftlint is currently installed in the system paths.
    # @return  [Bool]
    #
    def swiftlint_installed?
      `which swiftlint`.strip.empty? == false
    end
  end
end
