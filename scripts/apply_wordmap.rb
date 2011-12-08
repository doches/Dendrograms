#!/usr/bin/env ruby
#
# Apply a wordmap to all files with a given prefix
#
# Usage: apply_wordmap path/to/wordmap prefix/files

require 'progressbar'

if ARGV.size < 2
    STDERR.puts "Apply a wordmap to all files with a given prefix"
    STDERR.puts ""
    STDERR.puts "Usage: #{$0} path/to/wordmap prefix/files [-w|--warn]"
    exit(0)
end

@debug = ARGV.include?("-w") or ARGV.include?("--warn")
ARGV.reject! { |x| x == "-w" or x == "--warn" }

wordmap_path = ARGV.shift
prefix = ARGV.shift

def process(file)
	ext = file.split(".").pop
	
	txt = IO.readlines(file).join("").strip
	case ext
		when "dot"
			STDERR.puts "#{file} (DOT)"
			progress = ProgressBar.new("Applying",@wordmap.size)
			@wordmap.each_pair { |index,word| txt.gsub!("\"#{index}\"","\"#{word}\"") if not word.nil?; progress.inc }
			progress.finish
			return txt
		when "matrix"
			STDERR.puts "#{file} (MATRIX)"
			progress = ProgressBar.new("Applying",@wordmap.size)
			@wordmap.each_pair { |index,word| txt.gsub!(/^#{index}\:/,"#{word}:") if not word.nil?; progress.inc }
			progress.finish
			return txt
		when "txt"
			STDERR.puts "#{file} (TXT)"
			progress = ProgressBar.new("Applying",@wordmap.size)
			@wordmap.each_pair { |index,word| txt.gsub!("<#{index}>",word) if not word.nil?; progress.inc }
			progress.finish
			return txt
		when "graph"
			STDERR.puts "#{file} (GRAPH)"
			progress = ProgressBar.new("Applying",@wordmap.size*2)
			@wordmap.each_pair { |index,word| txt.gsub!(/^#{index}\t/,"#{word}\t") if not word.nil?; progress.inc }
			@wordmap.each_pair { |index,word| txt.gsub!(/\t#{index}\t/,"\t#{word}\t") if not word.nil?; progress.inc }
			progress.finish
			return txt
		else
			STDERR.puts "Unrecognised file extension \"#{ext}\"" if @debug
			return nil
	end
end

@wordmap = {}
IO.foreach(wordmap_path) do |line|
	word,index = *(line.strip.split(/\s+/))
	index = index.to_i
	@wordmap[index] = word if @wordmap[index].nil?
end

Dir.glob("#{prefix}*").each do |file|
	new_filename = file.split(".").reject { |x| x == "human" }
	ext = new_filename.pop
	new_filename = new_filename.push("human").push(ext).join(".")
	if not File.exists?(new_filename)
	  txt = process(file)
	  if not txt.nil?
		  fout = File.open(new_filename,'w')
		  fout.puts txt
		  fout.close
		end
	end
end
