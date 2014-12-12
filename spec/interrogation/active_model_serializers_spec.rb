require 'spec_helper'

describe RockDoc::Interrogation::ActiveModelSerializers do
  let(:doc) { RockDoc.new }

  describe ".interrogate_resources" do
    subject(:result) { described_class.interrogate_resources(doc: doc) }
    it "generates a list of resource configurations" do
      expect(result.map(&:class)).to match_array [RockDoc::Configuration::Resource]*3
    end

    it "sets the model class for each configuration" do
      expect(result.map(&:resource_class)).to match_array [Work, Character, Quote]
    end

    it "sets the serializer class for each configuration" do
      expect(result.map(&:serializer)).to match_array [WorkSerializer, CharacterSerializer, QuoteSerializer]
    end

    it "sets the configuration name for each configuration" do
      expect(result.map(&:configuration_name)).to match_array ["work", "character", "quote"]
    end
  end
end
