defmodule GitBoy.LicensesTest do
  use ExUnit.Case, async: true
  alias GitBoy.Licenses.License

  @valid_license_attrs %{
    "key" => "mit",
    "name" => "MIT License"
  }

  @invalid_license_attrs %{}

  describe "License.parse/1" do
    test "returns a License struct given valid attributes" do
      assert %License{} = License.parse(@valid_license_attrs)
    end

    test "returns nil given invalid attributes" do
      assert License.parse(@invalid_license_attrs) == nil
    end
  end
end
