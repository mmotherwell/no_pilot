# frozen_string_literal: true
require_relative "no_pilot/version"
require_relative "no_pilot/cli"

require "rake"
require "chusaku"
require "chusaku/version"
require "chusaku/parser"
require "chusaku/routes"

module NoPilot
  DEFAULT_CONTROLLERS_PATTERN = "**/*_controller.rb".freeze
  DEFAULT_EXCLUSION_PATTERN = "vendor/**/*_controller.rb".freeze

  class Error < StandardError; end

  class << self
    # The main method to run NoPilot. Creates Controller tests for every route
    #
    #   # @route GET /waterlilies/:id (waterlilies)
    #   def show
    #     # ...
    #   end
    #
    # @param flags [Hash] CLI flags
    # @return [Integer] 0 on success, 1 on error
    def call(flags = {})
      @flags = flags
      @routes = Chusaku::Routes.call
      @changed_files = []
      controllers_pattern = @flags[:controllers_pattern] || DEFAULT_CONTROLLERS_PATTERN
      controllers_paths = Dir.glob(Rails.root.join(controllers_pattern))

      @routes.each do |controller, actions|
        next unless controller

        controller_class = "#{controller.underscore.camelize}Controller".constantize
        action_method_name = actions.keys.first&.to_sym
        next unless !action_method_name.nil? && controller_class.method_defined?(action_method_name)

        source_path = controller_class.instance_method(action_method_name).source_location&.[](0)
        next unless controllers_paths.include?(source_path)

        generate_request_spec_file(
          controller_class: controller_class.to_s.split(" ")[0],
          path: source_path.gsub("app/controllers", "spec/requests").gsub("controller.rb", "spec.rb"),
          actions: actions
        )
      end

      output_results
    end

    # Load Rake tasks for Chusaku. Should be called in your project's `Rakefile`.
    #
    # @return [void]
    def load_tasks
      Dir[File.join(File.dirname(__FILE__), "tasks", "**/*.rake")].each do |task|
        load(task)
      end
    end

    private

    # Adds annotations to the given file.
    #
    # @param path [String] Path to file
    # @param actions [Hash<String, Hash>] List of valid action data for the controller
    # @return [void]
    def generate_request_spec_file(controller_class:, path:, actions:)
      return true_with_note("Already exists: #{path}") if File.exist?(path)
      return true_with_note("Not A Scaffold") unless (model_class_name = model_class(controller_class))

      ap controller_class
      ap model_class(controller_class)
      ap path
      ap actions

      puts render_request_spec(
        class_name: model_class_name,
        lets: render_lets(model_class_name, model_class(controller_class))
      )

      abort
      return true
      write_to_file(path: path, parsed_file: parsed_file)
    end

    def model_class(controller_class)
      model_class_name = controller_class.gsub("Controller", "").singularize
      model_class_name.constantize
    rescue
      false
    end

    def render_lets(model_class_name, model_class)
      valid_params = FactoryBot.build(model_class_name.to_sym).attributes
      ap valid_params
      abort

      renderer("params.rb.tt").result(binding)
    end

    def valid_values_for(model_class)
      relevant_columns_by_type(model_class).each do |column|
        [column.name, valid_value(column.type)]
      end
    end

    def relevant_columns_by_type(model_class)
      model_class.columns.reject { |column| %w[id created_at updated_at].include?(column.name) }
    end

    def render_request_spec(class_name:, lets: "", describes: "")
      renderer("request_spec.rb.tt").result(binding)
    end

    def renderer(template_name)
      template = File.read(template_include_path + template_name)
      ERB.new(template, trim_mode: '-')
    end

    def template_include_path
      File.expand_path(File.dirname(__FILE__)) + "/templates/"
    end

    # Adds annotations to the given file.
    #
    # @param path [String] Path to file
    # @param actions [Hash<String, Hash>] List of valid action data for the controller
    # @return [void]
    def annotate_file(path:, actions:)
      parsed_file = Chusaku::Parser.call(path: path, actions: actions.keys)
      parsed_file[:groups].each_cons(2) do |prev, curr|
        clean_group(prev)
        next unless curr[:type] == :action

        route_data = actions[curr[:action]]
        next unless route_data.any?

        annotate_group(group: curr, route_data: route_data)
      end

      raise "path: #{path}, parsed_file: #{parsed_file}"
      write_to_file(path: path, parsed_file: parsed_file)
    end

    # Given a parsed group, clean out its contents.
    #
    # @param group [Hash] { type => Symbol, body => String }
    # @return {void}
    def clean_group(group)
      return unless group[:type] == :comment

      group[:body] = group[:body].gsub(/^\s*#\s*@route.*$\n/, "")
      group[:body] =
        group[:body].gsub(%r{^\s*# (GET|POST|PATCH/PUT|DELETE) /\S+$\n}, "")
    end

    # Add an annotation to the given group given by Chusaku::Parser that looks
    # like:
    #
    #   @route GET /waterlilies/:id (waterlilies)
    #
    # @param group [Hash] Parsed content given by Chusaku::Parser
    # @param route_data [Hash] Individual route data given by Chusaku::Routes
    # @return [void]
    def annotate_group(group:, route_data:)
      whitespace = /^(\s*).*$/.match(group[:body])[1]
      route_data.reverse_each do |datum|
        comment = "#{whitespace}# #{annotate_route(**datum)}\n"
        group[:body] = comment + group[:body]
      end
    end

    # Generate route annotation.
    #
    # @param verb [String] HTTP verb for route
    # @param path [String] Rails path for route
    # @param name [String] Name used in route helpers
    # @param defaults [Hash] Default parameters for route
    # @return [String] "@route <verb> <path> {<defaults>} (<name>)"
    def annotate_route(verb:, path:, name:, defaults:)
      annotation = "@route #{verb} #{path}"
      if defaults&.any?
        defaults_str =
          defaults
            .map { |key, value| "#{key}: #{value.inspect}" }
            .join(", ")
        annotation += " {#{defaults_str}}"
      end
      annotation += " (#{name})" unless name.nil?
      annotation
    end

    # Write annotated content to a file if it differs from the original.
    #
    # @param path [String] File path to write to
    # @param parsed_file [Hash] Hash mutated by {#annotate_group}
    # @return [void]
    def write_to_file(path:, parsed_file:)
      new_content = new_content_for(parsed_file)
      return if parsed_file[:content] == new_content

      !@flags.include?(:dry) && perform_write(path: path, content: new_content)
      @changed_files.push(path)
    end

    # Extracts the new file content for the given parsed file.
    #
    # @param parsed_file [Hash] { groups => Array<Hash> }
    # @return [String] New file content
    def new_content_for(parsed_file)
      parsed_file[:groups].map { |pf| pf[:body] }.join
    end

    # Wraps the write operation. Needed to clearly distinguish whether it's a
    # write in the test suite or a write in actual use.
    #
    # @param path [String] File path
    # @param content [String] File content
    # @return [void]
    def perform_write(path:, content:)
      File.open(path, file_mode) do |file|
        if file.respond_to?(:test_write)
          file.test_write(content, path)
        else
          file.write(content)
        end
      end
    end

    # When running the test suite, we want to make sure we're not overwriting
    # any files. `r` mode ensures that, and `w` is used for actual usage.
    #
    # @return [String] 'r' or 'w'
    def file_mode
      File.instance_methods.include?(:test_write) ? "r" : "w"
    end

    # Output results to user.
    #
    # @return [Integer] 0 for success, 1 for error
    def output_results
      puts(output_copy)
      exit_code = 0
      exit_code = 1 if @changed_files.any? && @flags.include?(:error_on_annotation)
      exit_code
    end

    # Determines the copy to be used in the program output.
    #
    # @return [String] Copy to be outputted to user
    def output_copy
      return "Controller files unchanged." if @changed_files.empty?

      copy = changes_copy
      copy += "NoPilot has finished running."
      copy += "\nThis was a dry run so no files were changed." if @flags.include?(:dry)
      copy += "\nExited with status code 1." if @flags.include?(:error_on_annotation)
      copy
    end

    # Returns the copy for changed files if `--verbose` flag is passed.
    #
    # @return [String] Copy for changed files
    def changes_copy
      return "" unless @flags.include?(:verbose)

      @changed_files.map { |file| "Annotated #{file}" }.join("\n") + "\n"
    end

    def true_with_note(note)
      Rails.logger.info { note.yellow }
    end
  end
end
