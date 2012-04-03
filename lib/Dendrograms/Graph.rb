module Dendrograms

# Loads a graph from a .pairs file, and computes the number of edges between sets of nodes

class Graph
  attr_reader :nodes
  
  # Load a .pairs file
  def initialize(pairs)
    @nodes = {}
    @edges = {}
    
    IO.foreach(pairs) do |line|
      from, to = *(line.strip.split(/\s+/).map { |x| x.to_i })
      @nodes[from] = true
      @nodes[to] = true
      @edges[edge_key(from,to)] = true
      @edges[edge_key(to, from)] = true
    end
    @nodes = @nodes.keys
  end
  
  # Compute the number of edges between two sets of nodes
  def edges_between(set_a, set_b)
    count = 0
    set_a.each do |a|
      set_b.each do |b|
        count += 1 if @edges[edge_key(a,b)]
      end
    end
    return count
  end
  
  # Return a unique key for an edge between A and B
  def edge_key(a,b)
    "#{a}_#{b}".to_sym
  end
end

end