require 'spec_helper'

describe RockDoc do
  describe ".configure" do
  end

  describe "#generate" do
    it "returns a string" do
      expect(RockDoc.new.generate).to be_a String
    end

    it "renders via the configured renderer" do
      expect(RockDoc.global_configuration.renderer).to receive(:render)
      RockDoc.new.generate
    end
  end
end
