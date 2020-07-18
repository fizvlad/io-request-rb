require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
end

require 'rubocop/rake_task'
RuboCop::RakeTask.new(:rubocop) {}
namespace 'rubocop' do
  desc 'Generate rubocop TODO file.'
  task 'todo' do
    puts `rubocop --auto-gen-config`
  end
end

namespace 'yardoc' do
  desc 'Generate documentation'
  task 'generate' do
    puts `yardoc lib/*`
  end

  desc 'List undocumented elements'
  task 'undoc' do
    puts `yardoc stats --list-undoc lib/*`
  end
end

task :default => :test
