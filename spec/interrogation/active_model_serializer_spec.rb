require 'spec_helper'

describe RockDoc::Interrogation::ActiveModelSerializer do
  let(:doc) { RockDoc.new }
  describe(:resource_configuration) do
    RockDoc::Configuration::Resource.new.tap do |r|
      r.resource_class = Work
      r.serializer = WorkSerializer
      r.configuration_name = 'work'
    end
  end
  subject(:result) { described_class.interrogate_resources(doc: doc) }

end
