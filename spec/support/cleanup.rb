
def reset_documentation
  path = Rails.root.join("doc/api.markdown")
  File.delete(path) if File.exist?(path)
end

RSpec.configure do |config|
  config.before(:suite) do
    reset_documentation
  end

  config.after(:each) do
    reset_documentation
  end
end
