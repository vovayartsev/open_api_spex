defmodule OpenApiSpex.ObjectTest do
  use ExUnit.Case
  alias OpenApiSpex.{Cast, Schema}
  alias OpenApiSpex.Cast.{Object, Error}

  defp cast(ctx), do: Object.cast(struct(Cast, ctx))

  describe "cast/3" do
    test "when input is not an object" do
      schema = %Schema{type: :object}
      assert {:error, [error]} = cast(value: ["hello"], schema: schema)
      assert %Error{} = error
      assert error.reason == :invalid_type
      assert error.value == ["hello"]
    end

    test "input map can have atom keys" do
      schema = %Schema{type: :object}
      assert {:ok, map} = cast(value: %{one: "one"}, schema: schema)
      assert map == %{one: "one"}
    end

    test "converting string keys to atom keys when properties are defined" do
      schema = %Schema{
        type: :object,
        properties: %{
          one: nil
        }
      }

      assert {:ok, map} = cast(value: %{"one" => "one"}, schema: schema)
      assert map == %{one: "one"}
    end

    test "properties:nil, given unknown input property" do
      schema = %Schema{type: :object}
      assert cast(value: %{}, schema: schema) == {:ok, %{}}

      assert cast(value: %{"unknown" => "hello"}, schema: schema) ==
               {:ok, %{"unknown" => "hello"}}
    end

    test "with empty schema properties, given unknown input property" do
      schema = %Schema{type: :object, properties: %{}}
      assert cast(value: %{}, schema: schema) == {:ok, %{}}
      assert {:error, [error]} = cast(value: %{"unknown" => "hello"}, schema: schema)
      assert %Error{} = error
      assert error.reason == :unexpected_field
      assert error.name == "unknown"
      assert error.path == ["unknown"]
    end

    test "with schema properties set, given known input property" do
      schema = %Schema{
        type: :object,
        properties: %{age: nil}
      }

      assert cast(value: %{}, schema: schema) == {:ok, %{}}
      assert cast(value: %{"age" => "hello"}, schema: schema) == {:ok, %{age: "hello"}}
    end

    test "unexpected field" do
      schema = %Schema{
        type: :object,
        properties: %{}
      }

      assert {:error, [error]} = cast(value: %{foo: "foo"}, schema: schema)
      assert %Error{} = error
      assert error.reason == :unexpected_field
      assert error.path == ["foo"]
    end

    test "required fields" do
      schema = %Schema{
        type: :object,
        properties: %{age: nil, name: nil},
        required: [:age, :name]
      }

      assert {:error, [error, error2]} = cast(value: %{}, schema: schema)
      assert %Error{} = error
      assert error.reason == :missing_field
      assert error.name == :age
      assert error.path == [:age]

      assert error2.reason == :missing_field
      assert error2.name == :name
      assert error2.path == [:name]
    end

    test "fields with default values" do
      schema = %Schema{
        type: :object,
        properties: %{name: %Schema{type: :string, default: "Rubi"}}
      }

      assert cast(value: %{}, schema: schema) == {:ok, %{name: "Rubi"}}
      assert cast(value: %{"name" => "Jane"}, schema: schema) == {:ok, %{name: "Jane"}}
      assert cast(value: %{name: "Robin"}, schema: schema) == {:ok, %{name: "Robin"}}
    end

    test "explicitly passing nil for fields with default values (not nullable)" do
      schema = %Schema{
        type: :object,
        properties: %{name: %Schema{type: :string, default: "Rubi"}}
      }

      assert {:error, [%{reason: :null_value}]} = cast(value: %{"name" => nil}, schema: schema)
      assert {:error, [%{reason: :null_value}]} = cast(value: %{name: nil}, schema: schema)
    end

    test "explicitly passing nil for fields with default values (nullable)" do
      schema = %Schema{
        type: :object,
        properties: %{name: %Schema{type: :string, default: "Rubi", nullable: true}}
      }

      assert cast(value: %{"name" => nil}, schema: schema) == {:ok, %{name: nil}}
      assert cast(value: %{name: nil}, schema: schema) == {:ok, %{name: nil}}
    end

    test "default values in nested schemas" do
      child_schema = %Schema{
        type: :object,
        properties: %{name: %Schema{type: :string, default: "Rubi"}}
      }

      parent_schema = %Schema{
        type: :object,
        properties: %{child: child_schema}
      }

      assert cast(value: %{child: %{}}, schema: parent_schema) == {:ok, %{child: %{name: "Rubi"}}}

      assert cast(value: %{child: %{"name" => "Jane"}}, schema: parent_schema) ==
               {:ok, %{child: %{name: "Jane"}}}
    end

    test "cast property against schema" do
      schema = %Schema{
        type: :object,
        properties: %{age: %Schema{type: :integer}}
      }

      assert cast(value: %{}, schema: schema) == {:ok, %{}}
      assert {:error, [error]} = cast(value: %{"age" => "hello"}, schema: schema)
      assert %Error{} = error
      assert error.reason == :invalid_type
      assert error.path == [:age]
    end

    defmodule User do
      defstruct [:name]
    end

    test "optionally casts to struct" do
      schema = %Schema{
        type: :object,
        "x-struct": User,
        properties: %{
          name: %Schema{type: :string}
        }
      }

      assert {:ok, user} = cast(value: %{"name" => "Name"}, schema: schema)
      assert user == %User{name: "Name"}
    end

    test "validates maxProperties" do
      schema = %Schema{
        type: :object,
        properties: %{
          one: nil,
          two: nil
        },
        maxProperties: 1
      }

      assert {:error, [error]} = cast(value: %{one: "one", two: "two"}, schema: schema)
      assert %Error{} = error
      assert error.reason == :max_properties

      assert {:ok, _} = cast(value: %{one: "one"}, schema: schema)
    end

    test "validates minProperties" do
      schema = %Schema{
        type: :object,
        properties: %{
          one: nil,
          two: nil
        },
        minProperties: 1
      }

      assert {:error, [error]} = cast(value: %{}, schema: schema)
      assert %Error{} = error
      assert error.reason == :min_properties

      assert {:ok, _} = cast(value: %{one: "one"}, schema: schema)
    end
  end
end
