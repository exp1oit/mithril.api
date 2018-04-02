defmodule Mithril.ClientAPI.Client do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "clients" do
    field(:name, :string)
    field(:priv_settings, :map, default: %{"access_type" => "BROKER"})
    field(:redirect_uri, :string)
    field(:secret, :string)
    field(:settings, :map, default: %{})
    field(:is_blocked, :boolean, default: false)
    field(:block_reason, :string)

    field(:seed?, :boolean, default: false, virtual: true)

    belongs_to(:client_type, Mithril.ClientTypeAPI.ClientType)
    belongs_to(:user, Mithril.UserAPI.User)

    timestamps()
  end
end
