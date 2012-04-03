module Dendrograms

# Represents a single node in a dendrogram. Provides methods for transformation, and for computing likelihood
class DendrogramNode
  attr_accessor :index, :left, :right
  @@index = 0
  
  Epsilon = 0.00000000001
  
  def initialize(left, right)
    @left = left
    @right = right
    @index = @@index
    
    @@index += 1
    @child_cache = nil
  end
  
  def to_s
    [@index, 
     (@left.is_a?(DendrogramNode) ? "#{@left.index} (D)" : "#{@left} (G)"),
     (@right.is_a?(DendrogramNode) ? "#{@right.index} (D)" : "#{@right} (G)")].join("\t")
  end
  
  @@leaves = {}
  def DendrogramNode.resetLeaves
    @@leaves = {}
  end
    
  def DendrogramNode.linkToLeaf(node, leaf, wordmap)
    dot = []
    if @@leaves[leaf].nil?
      @@leaves[leaf] = @@leaves.size
      label = wordmap.nil? ? leaf : wordmap[leaf.to_s]
      dot.push "LEAF_#{@@leaves[leaf]} [shape=none, label=\"#{label}\"];"
    end
    dot.push "#{node} -- LEAF_#{@@leaves[leaf]};"
    return dot
  end
  
  def to_dot(graph, wordmap=nil, likelihood=false)
    dot = self.dot_node(graph,wordmap, likelihood)
    
    [@left, @right].each do |child|
      if child.is_a?(DendrogramNode)
        dot.push "INTERNAL_#{@index} -- INTERNAL_#{child.index};"
      else
        DendrogramNode.linkToLeaf("INTERNAL_#{@index}",child,wordmap).each { |x| dot.push x }
      end
    end
    
    return "\t#{dot.join("\n\t")}"
  end
  
  def dot_node(graph, wordmap=nil, likelihood=false, decorate=true)
    label = "\"\""
    shape = "point"
    color = "black"
    if likelihood != false
      theta = self.connectedness(graph)[0]
      theta = (theta*100).to_i/100.0
      shape = "none"
      label = "\"#{theta}\""
      color = theta > likelihood ? "blue" : "red"
    end
    if decorate
      return ["INTERNAL#{@index} [shape=#{shape},label=#{label},fontcolor=#{color},color=red];"]
    else
      return ["INTERNAL#{@index} [shape=point, label=\"\"];"]
    end
  end
  
  def hierarchy_dot(graph, wordmap, likelihood)
    dot = self.dot_node(graph,wordmap,likelihood,false)
    theta = self.connectedness(graph)[0]
    
    if theta < likelihood
      if @left.is_a?(DendrogramNode)
        dot.push "INTERNAL#{@index} -- INTERNAL#{@left.index};"
        dot.push @left.hierarchy_dot(graph,wordmap,likelihood)
      else  
        dot.push "INTERNAL#{@index} -- LEAF#{@left};"
        dot.push "LEAF#{@left} [shape=none, label=\"#{wordmap[@left.to_s]}\"];"
      end
      if @right.is_a?(DendrogramNode)
        dot.push "INTERNAL#{@index} -- INTERNAL#{@right.index};"
        dot.push @right.hierarchy_dot(graph,wordmap,likelihood)
      else  
        dot.push "INTERNAL#{@index} -- LEAF#{@right};"
        dot.push "LEAF#{@right} [shape=none, label=\"#{wordmap[@right.to_s]}\"];"
      end
    else
      dot.push self.children.map { |x| ["INTERNAL#{@index} -- LEAF#{x};","LEAF#{x} [shape=none, label=\"#{wordmap[x.to_s]}\"];"] }
#      dot.push self.children.map { |x| "LEAF#{x} [shape=none, label=\"#{wordmap[x.to_s]}\"];" }
#      dot.push self.children.map { |x| "INTERNAL#{@index} -- LEAF#{x};" }
    end
    
    dot.flatten
  end
  
  def children(force = false)
    if force or @child_cache.nil?
      @child_cache = [@left.is_a?(DendrogramNode) ? @left.children() : @left, 
                      @right.is_a?(DendrogramNode) ? @right.children() : @right].flatten
    end
    
    return @child_cache
  end
  
  def connectedness(graph)
    left_children = @left.is_a?(DendrogramNode) ? @left.children : [@left]
    right_children = @right.is_a?(DendrogramNode) ? @right.children : [@right]
    
    links = graph.edges_between(left_children, right_children).to_f
    max_links = (left_children.size * right_children.size)
    theta = links / max_links.to_f
    
    return [theta, max_links]
  end
  
  def likelihood(graph)
    theta,max_links = *self.connectedness(graph)
    theta = Epsilon if theta <= 0.0
    theta = 1.0-Epsilon if theta >= 1.0
#    l = (theta**links) * (1-theta)**(max_links-links)
    h = -theta*Math.log(theta) - (1-theta)*Math.log(1-theta)
    return -h * max_links
  end
  
  def mutable?
    @left.is_a?(DendrogramNode) or @right.is_a?(DendrogramNode)
  end
  
  def get_mutation
    # Are we swapping children with the left or the right child?if rand > 0.5
    child = nil
    if @left.is_a?(DendrogramNode)
      child = @left
    else
      child = @right
    end
    
    # Are we swapping the child's left or right child?
    do_left = false
    if rand > 0.5
      do_left = true
    end
    
    return {:child => child, :do_left => do_left, :local_child => (child == @left ? @right : @left)}
  end
  
  def mutate!(mutation = nil)
    mutation ||= self.get_mutation
    
    if mutation[:do_left]
      temp = mutation[:child].left
      mutation[:child].left = mutation[:local_child]
      if mutation[:local_child] == @left
        @left = temp
      else
        @right = temp
      end
      mutation[:local_child] = temp
    else
      temp = mutation[:child].right
      mutation[:child].right = mutation[:local_child]
      if mutation[:local_child] == @left
        @left = temp
      else
        @right = temp
      end
      mutation[:local_child] = temp
    end
    
    mutation[:child].children(true)
    self.children(true)
    return mutation
  end
end

# Takes a Graph, builds a dendrogram, and provides methods to sample, compute likelihood, and save (with optional info)
class Dendrogram
  attr_reader :graph, :likelihood, :mcmc_steps, :root
  
  def initialize(graph, tree_file=nil)
    @graph = graph
    @nodes = []
    @likelihoods = []
    @likelihood = 0
    @mcmc_steps = 0
    
    if tree_file
      index_map = {}
      IO.foreach(tree_file) do |line|
        if line =~ /^(\d+)\t(\d+) \(([D|G])\)\t(\d+) \(([D|G])\)/
          index, left, ltype, right, rtype = $1.to_i, $2.to_i, $3, $4.to_i, $5
          
          node = DendrogramNode.new(left, right)
          node.index = index
          @nodes.push node
          index_map[node.index] = node
          
          node.left = [left] if ltype == "D"
          node.right = [right] if rtype == "D"
        end
      end
      # Update mappings
      @nodes.each do |node|
        node.left = index_map[node.left[0]] if node.left.is_a?(Array)
        node.right = index_map[node.right[0]] if node.right.is_a?(Array)
        node.index = @nodes.index(node)
      end
      # Find root
      @root = @nodes.sort { |b,a| a.children.size <=> b.children.size }[0]
      
      # Update MCMC, if possible
      begin
        info_file = tree_file.gsub(".dendro",".info")
        if File.exists?(info_file)
          status = YAML.load_file(info_file)
          @mcmc_steps = status[:mcmc]
        end
      rescue
        STDERR.puts "Unable to load MCMC status from .info; carrying on."
      end
    else
      # Incrementally construct a balanced dendrogram
      remaining = graph.nodes.dup.sort_by { rand }
    
      while remaining.size > 1
        a = remaining.pop
        b = remaining.shift
      
        node = DendrogramNode.new(a,b)
        @nodes.push node
        remaining.push(node)
        remaining = remaining.sort_by { rand }
      end
    
      # Hold on to the last remaining node; it's the root
      @root = remaining.shift
    end
    
    # Initialise likelihoods
    @nodes.each_with_index { |node, index| @likelihoods[index] = node.likelihood(@graph) }
    # Compute starting likelihood
    @likelihood = @likelihoods.inject(0) { |s,x| s += x }
  end
  
  # Returns the mean node likelihood
  def mean_likelihood
    mean = @likelihoods.map { |x| Math.exp(x) }.inject(0) { |s,x| s += x } / @likelihoods.size.to_f
    STDERR.puts "Mean likelihood: #{mean}"
    return mean
  end
  
  def mean_theta
    @nodes.map { |x| x.connectedness(@graph)[0] }.inject(0) { |s,x| s += x } / @nodes.size.to_f
  end
  
  # Returns the median node connectednes
  def median_theta
    v = @nodes.map { |x| x.connectedness(@graph)[0] }
    return v[v.size/2]
  end
  
  def sample!
    mutate = nil
    while true
      node = @nodes[(rand*@nodes.size).to_i]
      if node.mutable?
        mutate = node
        break
      end
    end
    
    # Mutate tree
    mutation = mutate.mutate!
    
    old_likelihood = @likelihood
    self.update_likelihood([mutate, mutate.left, mutate.right])
    
    if not (@likelihood > old_likelihood or Math.log(rand) < @likelihood - old_likelihood)
      mutate.mutate!(mutation)
      self.update_likelihood([mutate, mutate.left, mutate.right])
    end
    @mcmc_steps += 1
    
    return @likelihood
  end
  
  def clusters
    @nodes.map { |node| node.children }
  end
  
  # Update the likelihood given two modified nodes
  def update_likelihood(nodes)
    # Compute new likelihood
    nodes.each do |node|
      if node.is_a?(DendrogramNode)
        @likelihood -= @likelihoods[node.index]
        @likelihoods[node.index] = node.likelihood(@graph)
        @likelihood += @likelihoods[node.index]
      end
    end
  end
  
  def save(tree_file, info_file)
    fout = File.open(tree_file,'w')
    fout.puts @nodes.map { |node| node.to_s }.join("\n")
    fout.close
    
    fout = File.open(info_file, 'w')
    fout.puts({:likelihood => @likelihood, :mcmc => @mcmc_steps}.to_yaml)
    fout.close
    
    self.to_dot(tree_file.gsub(/\.[^\.]+$/,".dot"))
  end
  
  def get_dot(wordmap=nil, likelihood=false)
    DendrogramNode.resetLeaves
    ["graph {",@nodes.map { |node| node.to_dot(@graph,wordmap,likelihood) }.join("\n"),"}"].join("\n")
  end
  
  def get_hierarchy_dot(wordmap=nil, likelihood=false)
    DendrogramNode.resetLeaves
    ["graph {", @root.hierarchy_dot(@graph, wordmap, likelihood).map { |x| "\t#{x}" }.join("\n"), "}"].join("\n")
  end
  
  def to_dot(dot_file, wordmap=nil, likelihood=false)
    fout = File.open(dot_file,'w')
    fout.puts self.get_dot(wordmap,likelihood)
    fout.close
  end
end

end