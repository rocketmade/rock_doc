# desc "Explaining what the task does"
# task :rock_doc do
#   # Task goes here
# end

desc 'Generate automatic API documentation'
task rock_doc: :environment do
  require 'rock_doc'

  Dir[Rails.root.join('doc/api/*.rb')].each do |f|
    require f
  end

  mkdir_p 'doc'
  File.open(Rails.root.join('doc/api.apib'), 'wb') do |f|
    f.write RockDoc.new.generate
  end
end
