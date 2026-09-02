defmodule Wyvern.LabelTest do
  use ExUnit.Case

  alias Wyvern.Label

  describe "Label" do
    test "unnamed label" do
      label = Label.new()

      assert label.name == nil
      assert is_reference(label.id)
    end

    test "named label" do
      label = Label.new("entry")

      assert label.name == "entry"
    end
  end
end
