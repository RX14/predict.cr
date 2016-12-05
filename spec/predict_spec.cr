require "yaml"
require "./spec_helper"

describe Predict do
  describe "VERSION" do
    it "matches shards.yml" do
      version = YAML.parse(File.read(File.join(__DIR__, "..", "shard.yml")))["version"].as_s
      version.should eq(Predict::VERSION)
    end
  end
end
