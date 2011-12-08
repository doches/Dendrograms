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
    
  def DendrogramNode.linkToLeaf(node, leaf)
    dot = []
    if @@leaves[leaf].nil?
      @@leaves[leaf] = @@leaves.size
      dot.push "LEAF_#{@@leaves[leaf]} [shape=none, label=\"#{leaf}\"];"
    end
    dot.push "#{node} -- LEAF_#{@@leaves[leaf]};"
    return dot
  end
  
  def to_dot(graph)
    label = "\"\""
    dot = ["INTERNAL_#{@index} [shape=point,label=#{label}];"]
    
    [@left, @right].each do |child|
      if child.is_a?(DendrogramNode)
        dot.push "INTERNAL_#{@index} -- INTERNAL_#{child.index};"
      else
        DendrogramNode.linkToLeaf("INTERNAL_#{@index}",child).each { |x| dot.push x }
      end
    end
    
    "\t#{dot.join("\n\t")}"
  end
  
  def children(force = false)
    if force or @child_cache.nil?
      @child_cache = [@left.is_a?(DendrogramNode) ? @left.children() : @left, 
                      @right.is_a?(DendrogramNode) ? @right.children() : @right].flatten
    end
    
    return @child_cache
  end
  
  def likelihood(graph)
    left_children = @left.is_a?(DendrogramNode) ? @left.children : [@left]
    right_children = @right.is_a?(DendrogramNode) ? @right.children : [@right]
    
    links = graph.edges_between(left_children, right_children).to_f
    max_links = (left_children.size * right_children.size)
    theta = links / max_links.to_f
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
  attr_reader :graph, :likelihood, :mcmc_steps
  
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
      @likelihood -= @likelihoods[node.index]
      @likelihoods[node.index] = node.likelihood(@graph)
      @likelihood += node.likelihood
    end
  end
  
  def save(tree_file, info_file)
    fout = File.open(tree_file,'w')
    fout.puts @nodes.map { |node| node.to_s }.join("\n")
    fout.close
    
    fout = File.open(info_file, 'w')
    fout.puts "Likelihood:\t#{@likelihood}\nMCMC Steps:\t#{@mcmc_steps}\n"
    fout.close
    
    self.to_dot(tree_file.gsub(/\.[^\.]+$/,".dot"))
  end
  
  def to_dot(dot_file)
    DendrogramNode.resetLeaves
    fout = File.open(dot_file,'w')
    fout.puts "graph {"
    fout.puts @nodes.map { |node| node.to_dot(@graph) }.join("\n")
    fout.puts "}"
    fout.close
  end
end
