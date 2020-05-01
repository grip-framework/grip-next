require "spec"
require "../src/parameters"

struct Gripen::Parameters
  # Tests adds of path and query parameters
  def public_add(param, value, &block)
    add param, value do |ex|
      yield ex
    end
  end
end

struct TestPath < Gripen::Parameters::Path
  def initialize(@val : Int32)
  end

  def self.from_string(str : String)
    new str.to_i
  end
end

struct TestOptionalQuery < Gripen::Parameters::OptionalQuery
  class_getter parameter_name = "optional"

  def initialize(@val : Int32)
  end

  def self.from_string(str : String)
    new str.to_i
  end
end

struct TestRequiredQuery < Gripen::Parameters::RequiredQuery
  class_getter parameter_name = "required"

  def initialize(@val : Int32)
  end

  def self.from_string(str : String)
    new str.to_i
  end
end

describe Gripen::Parameters do
  describe "#add" do
    it "adds a path with a valid value" do
      parameters = Gripen::Parameters.new
      parameters.public_add TestPath, "123" do |ex|
        fail "Exception not expected: #{ex}"
      end
    end

    it "adds a path with an invalid value" do
      parameters = Gripen::Parameters.new
      exception = nil
      parameters.public_add TestPath, "value" do |ex|
        exception = ex
      end
      exception.should be_a Gripen::Parameters::Error::InvalidValue
    end

    it "adds a query with an invalid value" do
      parameters = Gripen::Parameters.new
      exception = nil
      {TestOptionalQuery, TestRequiredQuery}.each do |query_class|
        parameters.public_add query_class, "value" do |ex|
          exception = ex
        end
        exception.should be_a Gripen::Parameters::Error::InvalidValue
      end
    end

    it "adds string parameter" do
      parameters = Gripen::Parameters.new
      parameters.public_add :param, "123" do |ex|
        fail "Exception not expected: #{ex}"
      end
    end
  end

  describe "#[]" do
    it "tries to fetch with no parameters available" do
      parameters = Gripen::Parameters.new
      expect_raises Gripen::Parameters::Error::NoParametersAvailable do
        parameters[TestPath]
      end
    end

    it "fetches a present path parameter" do
      parameters = Gripen::Parameters.new
      parameters.public_add TestPath, "123" { }
      parameters[TestPath].should eq TestPath.new 123
    end

    it "fetches a missing path parameter" do
      parameters = Gripen::Parameters.new
      parameters.public_add TestRequiredQuery, "123" { }
      ex = expect_raises Gripen::Parameters::Error::PathNotFound do
        parameters[TestPath]
      end
      ex.message.as(String).should end_with "TestPath"
    end

    it "fetches a present required query" do
      parameters = Gripen::Parameters.new
      parameters.public_add TestRequiredQuery, "123" { }
      parameters[TestRequiredQuery].should eq TestRequiredQuery.new 123
    end

    it "fetches a missing required query" do
      parameters = Gripen::Parameters.new
      parameters.public_add TestPath, "123" { }
      ex = expect_raises Gripen::Parameters::Error::QueryNotFound do
        parameters[TestRequiredQuery]
      end
      ex.message.as(String).should end_with "TestRequiredQuery"
    end

    it "fetches a string parameter" do
      parameters = Gripen::Parameters.new
      parameters.public_add :param, "123" { }
      parameters[:param].should eq "123"
    end
  end

  it "#[]? a present optional query" do
    parameters = Gripen::Parameters.new
    parameters.public_add TestOptionalQuery, "123" { }
    parameters[TestOptionalQuery]?.should eq TestOptionalQuery.new 123
  end

  it "#[]? a missing optional query" do
    parameters = Gripen::Parameters.new
    parameters.public_add TestPath, "123" { }
    parameters[TestOptionalQuery]?.should be_nil
  end

  it "splats with a Tuple" do
    parameters = Gripen::Parameters.new
    parameters.public_add TestPath, "123" { }
    parameters.public_add TestRequiredQuery, "123" { }
    parameters.public_add TestOptionalQuery, "123" { }
    path, required_query, optional_query = parameters[TestPath, TestRequiredQuery, TestOptionalQuery]
    path.should eq TestPath.new 123
    required_query.should eq TestRequiredQuery.new 123
    optional_query.should be_a TestOptionalQuery | Nil
    optional_query.should eq TestOptionalQuery.new 123
  end
end
