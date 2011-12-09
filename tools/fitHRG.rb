#!/usr/bin/ruby
Description = "Re-implementation, basically, of Clauset's fitHRG tool. Takes a .pairs file and fits a HRG over the graph\nProduces a .dendro file with the fit HRG and a .info file with information about the run; these are updated as higher-likelihood dendrograms are found.\n\nIf you pass in an optional partial dendrogra, fitHRG will continue sampling from that saved point."
Usage = "ruby #{$0} file.pairs [file.dendro]"
Num_Args = 1

require 'lib/Graph'
require 'lib/Dendrogram'
require 'lib/cli'

verbose = check_flag("-v","--verbose")
verbose_saved = check_flag("-s", "--saved")

if ARGV.size < Num_Args
  STDERR.puts Description
  STDERR.puts " "
  STDERR.puts "Usage: #{Usage}"
  exit(1)
end

pairs_file = ARGV.shift
dendrogram_file = pairs_file.gsub(/\.pairs$/,"-best.dendro")
info_file = pairs_file.gsub(/\.pairs$/,"-best.info")

graph = Graph.new(pairs_file)
dendrogram = nil
if ARGV.empty?
  dendrogram = Dendrogram.new(graph)
else
  dendrogram = Dendrogram.new(graph, ARGV.shift)
end

best_likelihood = dendrogram.sample!
best_steps = 0
start = Time.now.to_i
STDERR.puts ["MCMC","LIKELIHOOD","BEST LIKEL.","AT MCMC","TIME"].join("\t") if verbose
while true
  saved = false
  likelihood = dendrogram.sample!
  if likelihood > best_likelihood
    best_likelihood = likelihood
    dendrogram.save(dendrogram_file,info_file)
    best_steps = dendrogram.mcmc_steps
    saved = true
  end
  
  if (saved and verbose_saved) or dendrogram.mcmc_steps % 1000 == 0
    STDERR.puts [dendrogram.mcmc_steps, dendrogram.likelihood, best_likelihood, best_steps, "#{Time.now.to_i-start}s"].join("\t") if verbose
  end
end
