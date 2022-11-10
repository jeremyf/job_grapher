require "set"

# @see .plantuml_for
module JobGrapher
  DEFAULT_FILTER = ->(job) { true }
  DEFAULT_PATH_FORMATTER = -> (path) { path.sub(ENV['HOME'], "~") }
  # @api public
  #
  # Generate a PlantUML diagram
  #
  # @param dirs [Array<String>] the directories to check for jobs and
  #        performance.
  # @param path_formatter [String] for file names, remove this from
  #        the beginning of that path.
  # @param filter [#call] the filter to call which when true means to
  #        include the given job's class name in the generated graph.
  #        When false, skip this job.
  # @param buffer [#puts] the buffer to which we'll "#puts" the graph.
  #
  # @see https://plantuml.com
  def self.plantuml_for(dirs:, path_formatter: DEFAULT_PATH_FORMATTER, filter: DEFAULT_FILTER, buffer: STDOUT)
    graph = Graph.new(filter: filter)
    Array(dirs).each do |dir|
      PerformInformation.each_from(dir) do |info|
        graph.add_perform_info(info)
      end

      JobDeclaration.each_from(dir) do |declaration|
        graph.add_declaration(declaration)
      end
    end
    graph.to_plantuml(path_formatter: path_formatter, buffer: buffer)
    true
  end

  # An accumulator class for adding declarations and perform information, then
  # rendering that accumlated data (see #to_plantuml)
  class Graph
    def initialize(filter:)
      @performances = []
      @declarations = []
      @filter = filter
    end

    # @param declaration [JobGrapher::JobDeclaration]
    def add_declaration(declaration)
      @declarations << declaration
    end

    # @param info [JobGrapher::PerformInformation]
    def add_perform_info(info)
      @performances << info
    end

    # @param buffer [#puts] where are we putting the data we've gathered?
    # @param path_formatter [#call] how we format a raw path to a file
    def to_plantuml(buffer:, path_formatter: DEFAULT_PATH_FORMATTER)
      buffer.puts "@startuml"
      resolver = Resolver.new(
        declarations: @declarations,
        performances: @performances,
        filter: @filter,
        path_formatter: path_formatter
      )

      resolver.edges.each do |edge|
        buffer.puts "(#{edge.from}) --> (#{edge.to})"
      end
      buffer.puts "@enduml"
    end

    class Resolver
      def initialize(declarations:, performances:, filter:, path_formatter:)
        @declarations = declarations
        @performances = performances
        @filter = filter
        @path_formatter = path_formatter
        compile!
      end

      attr_reader :edges, :filter, :path_formatter

      Edge = Struct.new(:from, :to, keyword_init: true)

      # For each performance's job_class_name_candidates find the corresponding
      # constant.
      def compile!
        @edges = Set.new
        jobs = @declarations.map(&:job_class_name)
        @performances.each do |perf|
          from = path_formatter.call(perf.invoking_constant)
          to = perf.job_class_name_candidates.find do |cand|
            jobs.include?(cand)
          end
          next unless filter.call(to)
          @edges << Edge.new(from: from, to: to)
        end
      end
    end
  end

  # This module extracts the qualified constant name for a declared
  # class/module.  We make a fundamental assumption that folks are properly
  # indenting their nested classes and modules.
  module QualifiedConstantNameExtractor
    NAMESPACE_REGEXP = %r{^(?<padding> *)(class|module) +(?<namespace>[\w:]+)[ \n]}
    # @param path [String]
    # @param line_number [Integer, #to_i]
    # @return [String]
    def self.call(path:, line_number:)
      declarations = module_delcarations_for(path: path, line_number: line_number.to_i)
      determine_namespace_from(declarations: declarations)
    end

    def self.module_delcarations_for(path:, line_number:)
      declarations = []

      # Should we read this in reverse order?
      File.readlines(path).each_with_index do |line, index|
        break if index + 1 > line_number
        match = NAMESPACE_REGEXP.match(line)
        next unless match
        declarations << match
      end
      declarations
    end
    private_class_method :module_delcarations_for

    def self.determine_namespace_from(declarations:)
      # Based on convention, this would be a 40 deep module; gods have
      # mercy.
      current_padding_size = 80
      qualified_module_name = []
      # This will be easier to do if we reverse things; Because we can
      # handle files that have multiple module declarations.
      declarations.reverse.each do |dec|
        if dec[:padding].length < current_padding_size
          current_padding_size = dec[:padding].length
          qualified_module_name.unshift(dec[:namespace])
        end
      end
      qualified_module_name.join("::")
    end
    private_class_method :determine_namespace_from
  end


  # This class has two responsibilities:
  #
  # 1. A simple data structure (e.g. an instance of the class)
  # 2. Building the data structure from the given directory; see .each_from
  class PerformInformation
    def self.each_from(dir)
      command = %(rg "^ *[^#]*Job\\.(perform|_*send_*|public_send)" #{dir} -g '!spec/' -n)
      `#{command}`.split("\n").each do |line|
        parser = Parser.new(line)
        info = new(
          path: parser.path,
          invoking_constant: parser.invoking_constant,
          job_class_name_candidates: parser.job_class_name_candidates
        )
        yield(info)
      end
    end

    def initialize(path:, invoking_constant:, job_class_name_candidates:)
      @path = path
      @invoking_constant = invoking_constant
      @job_class_name_candidates = job_class_name_candidates
    end

    attr_reader :path, :invoking_constant, :job_class_name_candidates

    class Parser
      LINE_REGEXP = %r{(?<path>[^:]*):(?<line_number>[^:]*):(?<content>.*)}
      JOB_REGEXP = %r{(?<job>[\w:]+Job)\.(perform|_*send_*|public_send)}
      def initialize(grep_result_line)
        @grep_result_line = grep_result_line
        match = LINE_REGEXP.match(grep_result_line)
        @path = match[:path].strip
        @line_number = match[:line_number].to_i
        @content = match[:content]
        @invoking_constant = QualifiedConstantNameExtractor.call(path: @path, line_number: @line_number)

        @job = JOB_REGEXP.match(@content)[:job]

        if @invoking_constant.length == 0
          @job_class_name_candidates = [@job]
          @invoking_constant = @path
        else
          @job_class_name_candidates = determine_job_candidates_from(job: @job, namespace: @invoking_constant)
        end
      end

      attr_reader :path
      attr_reader :invoking_constant
      attr_reader :job_class_name_candidates

      private
      def determine_job_candidates_from(job:, namespace:)
        candidates = [job]
        slugs = namespace.split("::")
        slugs.each_with_index do |mod, i|
          candidates << slugs[0..i].join("::") + "::" + job
        end
        candidates
      end
    end

  end

  # This class has two responsibilities:
  #
  # 1. Determining all of the class declarations of a Job; see .each_from
  # 2. Exposing the job's class name; see #job_class_name
  #
  # The instance of the class is a simple data structure.  The .each_from yields
  # each data structure for matching declarations.
  class JobDeclaration
    def self.each_from(dir)
      command = %(rg "^ *class ([\\w:]+)Job <" #{dir} -g '!spec/' -n)
      `#{command}`.split("\n").each do |line|
        yield(new(line))
      end
    end

    include Comparable
    def <=>(other)
      job_class_name <=> other.job_class_name
    end

    LINE_REGEXP = %r{(?<path>[^:]*):(?<line_number>[^:]*):(?<content>.*)}
    JOB_REGEXP = %r{(?<job>[\w:]+Job) \<}
    def initialize(grep_result_line)
      @grep_result_line = grep_result_line
      match = LINE_REGEXP.match(grep_result_line)
      @path = match[:path].strip
      @line_number = match[:line_number].to_i
      @content = match[:content]
      @job = JOB_REGEXP.match(@content)[:job]
      @job_class_name = QualifiedConstantNameExtractor.call(path: @path, line_number: @line_number)
    end

    attr_reader :job_class_name
  end
end
