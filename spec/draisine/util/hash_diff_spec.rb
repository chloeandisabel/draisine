require "spec_helper"

describe Draisine::HashDiff do
  subject { described_class }

  describe ".diff" do
    it "returns added keys" do
      h1 = { a: :b }
      h2 = { a: :b, c: :d }
      expect(subject.diff(h1, h2).added).to eq([:c])
    end

    it "returns removed keys" do
      h1 = { a: :b, c: :d }
      h2 = { c: :d }
      expect(subject.diff(h1, h2).removed).to eq([:a])
    end

    it "returns changed keys" do
      h1 = { a: :b }
      h2 = { a: :c }
      expect(subject.diff(h1, h2).changed).to eq([:a])
    end

    it "returns unchanged keys" do
      h1 = { a: :b }
      h2 = { a: :b }
      expect(subject.diff(h1, h2).unchanged).to eq([:a])
    end

    it "supports custom equality functions" do
      a = { a: 0 }
      b = { a: 1 }
      c = { a: 4 }
      equality_function = -> (a, b) { a % 4 == b % 4 }
      expect(subject.diff(a, b, equality_function).changed).to eq([:a])
      expect(subject.diff(a, c, equality_function).changed).to eq([])
    end
  end

  describe ".sf_diff" do
    it "works" do
      a = { a: '2014-01-01T00:00:00-03:00' }
      b = { a: '2014-01-01T03:00:00+00:00' }
      expect(subject.sf_diff(a, b).unchanged).to eq([:a])
    end
  end
end
