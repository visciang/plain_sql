defmodule PlainSQL.Fragment do
  @moduledoc """
  A piece of SQL text together with the values bound inside it.

  A Fragment is an ordered list of parts. Rendering assigns placeholders in part order.
  A Fragment holds no nested Fragment. Splicing flattens the inner parts into the outer list.
  The Empty Fragment is `%PlainSQL.Fragment{parts: []}`.
  """

  @typedoc """
  One part of a Fragment.

  - `{:text, t}` renders `t` verbatim.
  - `{:binding, v}` renders one placeholder and adds `v` to the params.
  - `{:list, values}` renders one placeholder per element inside parentheses.
  - `{:identifier, name}` renders `name` inside the delimiter pair of the Dialect.
  """
  @type part ::
          {:text, String.t()}
          | {:binding, term()}
          | {:list, [term()]}
          | {:identifier, String.t()}

  @type t :: %__MODULE__{parts: [part()]}

  defstruct parts: []
end
