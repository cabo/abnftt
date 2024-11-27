task :default => :build

task :i => "lib/abnfgrammar.rb" do
  sh "gebuin abnftt.gemspec"
end

task :build => "lib/abnfgrammar.rb" do
  sh "gem build abnftt.gemspec"
end

file "lib/abnfgrammar.rb" => "lib/abnfgrammar.treetop" do
  sh "tt lib/abnf.treetop"
end

