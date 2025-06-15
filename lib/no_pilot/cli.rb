require "optparse"
require "no_pilot"
require "chusaku/cli"

module NoPilot
  # Enables flags for the `chusaku` executable.
  class CLI < Chusaku::CLI
    # Parse CLI flags, if any, and handle applicable behaviors.
    #
    # @param args [Array<String>] CLI arguments
    # @return [Integer] 0 on success, 1 on error
    def call(args = ARGV)
      optparser.parse!(args)
      check_for_rails_project
      NoPilot.call(options)
    rescue NotARailsProject
      warn("Please run NoPilot from the root of your Rails project.")
      STATUS_ERROR
    rescue Finished
      STATUS_SUCCESS
    end

    private

    # Returns an instance of OptionParser with supported flags.
    #
    # @return [OptionParser] Preconfigured OptionParser instance
    def optparser
      OptionParser.new do |opts|
        opts.banner = "Usage: no_pilot [options]"
        opts.set_summary_width(35)
        add_debug_flag(opts)
        add_dry_run_flag(opts)
        add_error_on_annotation_flag(opts)
        add_controllers_pattern_flag(opts)
        add_verbose_flag(opts)
        add_version_flag(opts)
        add_help_flag(opts)
      end
    end

    # Adds `--debug` flag.
    #
    # @param opts [OptionParser] OptionParser instance
    # @return [void]
    def add_debug_flag(opts)
      opts.on("--debug", "Shows output messages via the logger") do
        @options[:debug] = true

        Rails.logger.level = :info
        Rails.logger = Logger.new(STDOUT)
      end
    end

    # Adds `--dry-run` flag.
    #
    # @param opts [OptionParser] OptionParser instance
    # @return [void]
    def add_dry_run_flag(opts)
      opts.on("--dry-run", "Run without file modifications") do
        @options[:dry] = true
      end
    end

    # Adds `--exit-with-error-on-creation` flag.
    #
    # @param opts [OptionParser] OptionParser instance
    # @return [void]
    def add_error_on_annotation_flag(opts)
      opts.on("--exit-with-error-on-creation", "Fail if any file was created") do
        @options[:error_on_annotation] = true
      end
    end

    # Adds `--verbose` flag.
    #
    # @param opts [OptionParser] OptionParser instance
    # @return [void]
    def add_verbose_flag(opts)
      opts.on("--verbose", "Print all created files") do
        @options[:verbose] = true
      end
    end

    # Adds `--version` flag.
    #
    # @param opts [OptionParser] OptionParser instance
    # @return [void]
    def add_version_flag(opts)
      opts.on("-v", "--version", "Show NoPilot version number and quit") do
        puts(NoPilot::VERSION)
        raise Finished
      end
    end
  end
end
