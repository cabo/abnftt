task :default => :build

task :build => "lib/abnfgrammar.rb" do
  sh "gem build abnftt.gemspec"
end

file "lib/abnfgrammar.rb" => "lib/abnfgrammar.treetop" do
  sh "tt lib/abnf.treetop"
end

