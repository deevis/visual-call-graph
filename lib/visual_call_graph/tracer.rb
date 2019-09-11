
class Tracer
  def initialize(options)
    @graph = GraphManager.new(options)
    @tracer = build_tracer(options)
  end

  def enable
    @tracer.enable
  end

  def disable
    @tracer.disable
  end

  def generate_output_png
    @graph.output

    puts "Call graph created with a total of #{node_count}."
  end

  private

  # options:  {
  #              include_path_contains: [],
  #              exclude_path_contains: []
  #           }
  # include_path_contains take precedence over exclude_path_contains
  #
  def build_tracer(options={})
    include_path_contains = options[:include_path_contains]
    exclude_path_contains = options[:exclude_path_contains]
    TracePoint.new(:call, :return) { |event|
      # Avoid tracing myself...
      next if  event.defined_class == self.class
      # Ensure include_path_contains run first and will avoid exclude rules
      include_matched = false
      if !include_path_contains.nil?
        include_path_contains.each do |always_include_paths_containing_this|
          if event.path.include?(always_include_paths_containing_this)
            include_matched = true
            break
          end
        end
      end
      # Avoid tracing paths including strings specified in exclude_path_contains option 
      if !include_matched && !exclude_path_contains.nil?
        skip_tracing = false
        exclude_path_contains.each do |exlude_paths_containing_this|
          if event.path.include?(exlude_paths_containing_this)
            skip_tracing = true
            break
          end
        end
        next if skip_tracing
      end
      case event.event
      when :return
        @graph.pop
      when :call
        puts "TRACING: #{event.path}"
        @graph.add_edges(event)
      end
    }
  end

  def node_count
    "#{@graph.node_count} #{(@graph.node_count > 1 ? 'nodes' : 'node')}"
  end
end
