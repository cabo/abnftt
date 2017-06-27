task :default => :build

task :build => "lib/abnf.rb" do
  sh "gem build abnftt.gemspec"
end

file "lib/abnf.rb" => "lib/abnf.treetop" do
  sh "tt lib/abnf.treetop"
end

