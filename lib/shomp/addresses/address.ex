defmodule Shomp.Addresses.Address do
  use Ecto.Schema
  import Ecto.Changeset

  alias Shomp.Accounts.User

  schema "addresses" do
    field :immutable_id, :string
    field :type, :string
    field :name, :string
    field :street, :string
    field :city, :string
    field :state, :string
    field :zip_code, :string
    field :country, :string, default: "US"
    field :is_default, :boolean, default: false
    field :label, :string
    field :use_as_billing, :boolean, virtual: true
    
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc """
  A changeset for creating and updating addresses.
  """
  def changeset(address, attrs) do
    address
    |> cast(attrs, [:type, :name, :street, :city, :state, :zip_code, :country, :is_default, :label, :user_id, :use_as_billing])
    |> validate_required([:type, :name, :street, :city, :state, :zip_code, :country, :user_id])
    |> validate_inclusion(:type, ["billing", "shipping"])
    |> validate_inclusion(:country, ["US"]) # US-only for MVP
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:street, min: 5, max: 200)
    |> validate_length(:city, min: 2, max: 100)
    |> validate_length(:state, min: 2, max: 50)
    |> validate_length(:zip_code, min: 5, max: 10)
    |> validate_length(:label, max: 50)
    |> validate_zip_code_format()
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  A changeset for creating addresses.
  """
  def create_changeset(address, attrs) do
    address
    |> changeset(attrs)
    |> generate_immutable_id()
    |> validate_required([:immutable_id])
    |> unique_constraint(:immutable_id)
  end

  @doc """
  A changeset for updating address default status.
  """
  def default_changeset(address, attrs) do
    address
    |> cast(attrs, [:is_default])
    |> validate_required([:is_default])
  end

  defp generate_immutable_id(changeset) do
    case get_change(changeset, :immutable_id) do
      nil ->
        # Generate a unique, immutable address ID
        address_id = Ecto.UUID.generate()
        put_change(changeset, :immutable_id, address_id)
      _ ->
        changeset
    end
  end

  defp validate_zip_code_format(changeset) do
    zip_code = get_change(changeset, :zip_code) || get_field(changeset, :zip_code)
    
    if zip_code && not Regex.match?(~r/^\d{5}(-\d{4})?$/, zip_code) do
      add_error(changeset, :zip_code, "must be a valid US ZIP code (12345 or 12345-6789)")
    else
      changeset
    end
  end
end
