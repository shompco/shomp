defmodule Shomp.Addresses do
  @moduledoc """
  The Addresses context.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.Addresses.Address

  @doc """
  Returns the list of addresses for a user.
  """
  def list_user_addresses(user_id, type \\ nil) do
    query = from a in Address, where: a.user_id == ^user_id
    
    query = case type do
      nil -> query
      type -> where(query, [a], a.type == ^type)
    end
    
    query
    |> order_by([a], [desc: a.is_default, desc: a.inserted_at])
    |> Repo.all()
  end

  @doc """
  Gets a single address.
  """
  def get_address!(id), do: Repo.get!(Address, id)

  @doc """
  Gets an address by immutable_id.
  """
  def get_address_by_immutable_id!(immutable_id) do
    Repo.get_by!(Address, immutable_id: immutable_id)
  end

  @doc """
  Creates an address.
  """
  def create_address(attrs \\ %{}) do
    case %Address{}
         |> Address.create_changeset(attrs)
         |> Repo.insert() do
      {:ok, address} = result ->
        # If this address is set as default, remove default from others of same type
        if address.is_default do
          set_default_address(address)
        end
        
        # If this is a shipping address and use_as_billing is checked, create billing address too
        if address.type == "shipping" && attrs["use_as_billing"] do
          create_billing_from_shipping(address, attrs)
        end
        
        result
      
      error -> error
    end
  end

  @doc """
  Creates a billing address from a shipping address.
  """
  def create_billing_from_shipping(shipping_address, attrs) do
    billing_attrs = %{
      "type" => "billing",
      "name" => shipping_address.name,
      "street" => shipping_address.street,
      "city" => shipping_address.city,
      "state" => shipping_address.state,
      "zip_code" => shipping_address.zip_code,
      "country" => shipping_address.country,
      "label" => shipping_address.label,
      "user_id" => shipping_address.user_id,
      "is_default" => attrs["is_default"] || false
    }
    
    case %Address{}
         |> Address.create_changeset(billing_attrs)
         |> Repo.insert() do
      {:ok, billing_address} ->
        # If this billing address is set as default, remove default from other billing addresses
        if billing_address.is_default do
          set_default_address(billing_address)
        end
        {:ok, billing_address}
      
      error -> error
    end
  end

  @doc """
  Updates an address.
  """
  def update_address(%Address{} = address, attrs) do
    case address
         |> Address.changeset(attrs)
         |> Repo.update() do
      {:ok, updated_address} ->
        # If this address is set as default, remove default from others of same type
        if updated_address.is_default do
          set_default_address(updated_address)
        end
        {:ok, updated_address}
      
      error -> error
    end
  end

  @doc """
  Deletes an address.
  """
  def delete_address(%Address{} = address) do
    Repo.delete(address)
  end

  @doc """
  Sets an address as the default for its type.
  """
  def set_default_address(%Address{} = address) do
    Repo.transaction(fn ->
      # Remove default from other addresses of same type
      from(a in Address, 
        where: a.user_id == ^address.user_id and a.type == ^address.type and a.id != ^address.id)
      |> Repo.update_all(set: [is_default: false])
      
      # Set this address as default
      address
      |> Address.default_changeset(%{is_default: true})
      |> Repo.update()
    end)
  end

  @doc """
  Gets the default address for a user and type.
  """
  def get_default_address(user_id, type) do
    Address
    |> where([a], a.user_id == ^user_id and a.type == ^type and a.is_default == true)
    |> Repo.one()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking address changes.
  """
  def change_address(%Address{} = address, attrs \\ %{}) do
    Address.changeset(address, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for creating an address.
  """
  def change_address_creation(%Address{} = address, attrs \\ %{}) do
    Address.create_changeset(address, attrs)
  end

  @doc """
  Counts the number of addresses for a specific user.
  """
  def count_user_addresses(user_id) do
    Address
    |> where([a], a.user_id == ^user_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Counts the number of addresses for a specific user and type.
  """
  def count_user_addresses_by_type(user_id, type) do
    Address
    |> where([a], a.user_id == ^user_id and a.type == ^type)
    |> Repo.aggregate(:count, :id)
  end
end
