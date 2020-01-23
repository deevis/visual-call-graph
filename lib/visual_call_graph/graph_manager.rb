
require 'graphviz'

class GraphManager
  def initialize(options)
    start_label = (options[:start_label].presence) || "start"
    start_label.gsub!("\\\"", "'")

    @stack   = [start_label]
    @edges   = []
    @options = options
    @registered_lambdas = options[:registered_lambdas] || []
    @exclude_path_contains = @options[:exclude_path_contains] || []
    @g = GraphViz.new(:G, :type => :digraph)

    @g.add_node(start_label)
  end

  def add_edges(event)
    node = get_node_name(event) 
    # ruby-graphviz will blow up if nil is added as an edge
    stack_last = @stack.last || (@options[:start_label].presence) || "start"
    
    edge = [stack_last, node]

    @stack << node

    return if @edges.include?(edge)

    @edges << edge
    @g.add_edge(*@edges.last)
  end

  def get_node_name(event)
    klass_name = event.defined_class.to_s
    if klass_name.start_with?("#<Class:")
      # Doh - we've got a Singleton class (probably cuz of a static method)
      matches = klass_name.match(/#<Class:(\w*).*/)
      klass_name = matches[1] rescue matches[0]
    end
    class_and_method = "#{klass_name}##{event.method_id}"
    if @options[:show_path]
      "#{class_and_method}\n#{event.path}".freeze
    elsif (registered_lambda = @registered_lambdas[class_and_method]) 
      puts "Found lambda for #{class_and_method} -calling with binding and #{@exclude_path_contains}"
      value = registered_lambda.call(event.binding, @exclude_path_contains)
      "#{class_and_method}\n#{value}".freeze
    else
      class_and_method.freeze
    end
  end

  def output
    format = @options[:format] || :png
    path   = @options[:path] || "#{Dir.pwd}/call_graph.#{format.to_s}"

    @g.output(format.to_sym => path)
  end

  def node_count
    @g.node_count
  end

  def pop
    @stack.pop
  end
end
