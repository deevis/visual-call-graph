
require 'visual_call_graph/graph_manager'
require 'visual_call_graph/tracer'

module VisualCallGraph
  extend self

  @@sql_formatter=->(binding, exclude_caller_path_contains) do 
    value = binding.eval("sql")
    value.gsub!("INNER", "\nINNER")
    value.gsub!("FROM", "\nFROM")
    value.gsub!("WHERE", "\nWHERE")
    value.gsub!("ORDER", "\nORDER")
    value.gsub!("LEFT", "\nLEFT")
    value.gsub!("AND", "\nAND")
    value.gsub!("\n\n","\n")
    value.gsub!("\\\"", "'")
    if value.length > 512 
      value = value[0,512] + "..."
    end
    # be sure to call 'caller' with the passed binding to get the correct callstack
    callstack = binding.eval("caller")
    caller_string = if exclude_caller_path_contains.nil?
      # puts "exclude_caller_path_contains wasn't set - returning first item"
      callstack.first
    else
      # puts "exclude_caller_path_contains: #{exclude_caller_path_contains}"      
      callstack.detect do |backtrace_string|
        next if backtrace_string.index("visual_call_graph")
        allow_this = true
        exclude_caller_path_contains.each do |exclude_if_found_in_path|
          if backtrace_string.index(exclude_if_found_in_path)
            allow_this = false
            break
          end
        end
        allow_this
      end
    end
    if caller_string
      value = "#{caller_string.split(/\//).last(3).join("/")}\n#{value}" rescue "#{caller_string}\n#{value}"
    end
    return value
  end

  def trace(options = {})
    unless block_given?
      puts "Block required!"
      return
    end

    if options[:use_rails_config] == true 
      options["Mysql2::Client#query"] ||= @@sql_formatter
      options[:include_path_contains] ||=  ["mysql2/client"]
      options[:exclude_path_contains] ||=  [".rvm", "gems"]
    end

    tracer = Tracer.new(options)

    tracer.enable
    yield
    tracer.disable

    tracer.generate_output_png
  end
end
