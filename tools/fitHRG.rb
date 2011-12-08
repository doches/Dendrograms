Description = "Re-implementation, basically, of Clauset's fitHRG tool. Takes a .pairs file and fits a HRG over the graph\nProduces a .dendro file with the fit HRG and a .info file with information about the run; these are updated as higher-likelihood dendrograms are found."
Usage = "ruby #{$0} file.pairs"
Num_Args = 1

if ARGV.size != Num_Args
  STDERR.puts Description
  STDERR.puts " "
  STDERR.puts "Usage: #{Usage}"
  exit(1)
end

require 'lib/Graph'
require 'lib/Dendrogram'

pairs_file = ARGV.shift
dendrogram_file = pairs_file.gsub(/\.pairs$/,"-best.dendro")
info_file = pairs_file.gsub(/\.pairs$/,"-best.info")

graph = Graph.new(pairs_file)
dendrogram = Dendrogram.new(graph)

best_likelihood = dendrogram.sample!
best_steps = 0
STDERR.puts ["MCMC STEPS","LIKELIHOOD","BEST LIKELIHOOD","AT MCMC"].join("\t")
while true
  saved = false
  likelihood = dendrogram.sample!
  if likelihood > best_likelihood
    best_likelihood = likelihood
    dendrogram.save(dendrogram_file,info_file)
    best_steps = dendrogram.mcmc_steps
    saved = true
  end
  
  if saved or dendrogram.mcmc_steps % 1000 == 0
    STDERR.puts [dendrogram.mcmc_steps, dendrogram.likelihood, best_likelihood, best_steps].join("\t")
  end
end