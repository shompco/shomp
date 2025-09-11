defmodule Shomp.Stores.StoreKYCContext do
  @moduledoc """
  The StoreKYC context for managing store KYC submissions and verification.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.Stores.StoreKYC
  alias Shomp.Stores

  @doc """
  Gets or creates a KYC record for a store using string store_id.
  """
  def get_or_create_kyc_by_store_id(store_id_string) do
    case Stores.get_store_by_store_id(store_id_string) do
      nil ->
        {:error, :store_not_found}
      store ->
        get_or_create_kyc(store.id)
    end
  end

  @doc """
  Gets KYC by string store_id.
  """
  def get_kyc_by_store_id(store_id_string) do
    case Stores.get_store_by_store_id(store_id_string) do
      nil ->
        nil
      store ->
        get_kyc(store.id)
    end
  end

  @doc """
  Gets or creates a KYC record for a store using integer ID.
  """
  def get_or_create_kyc(store_id) do
    case get_kyc(store_id) do
      nil ->
        create_minimal_kyc(%{store_id: store_id})
      kyc ->
        {:ok, kyc}
    end
  end

  @doc """
  Gets KYC by user ID (finds any KYC record for any store owned by this user).
  """
  def get_kyc_by_user_id(user_id) do
    StoreKYC
    |> join(:inner, [kyc], store in assoc(kyc, :store))
    |> where([kyc, store], store.user_id == ^user_id)
    |> where([kyc], not is_nil(kyc.stripe_account_id))
    |> order_by([kyc], desc: kyc.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Gets KYC by store ID using integer ID.
  """
  def get_kyc(store_id) do
    StoreKYC
    |> where([k], k.store_id == ^store_id)
    |> Repo.one()
  end

  @doc """
  Creates a new KYC record.
  """
  def create_kyc(attrs \\ %{}) do
    %StoreKYC{}
    |> StoreKYC.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a minimal KYC record for Stripe Connect.
  """
  def create_minimal_kyc(attrs \\ %{}) do
    %StoreKYC{}
    |> StoreKYC.minimal_changeset(attrs)
    |> Repo.insert()
  end


  @doc """
  Gets KYC by Stripe account ID.
  """
  def get_kyc_by_stripe_account_id(stripe_account_id) do
    StoreKYC
    |> where([k], k.stripe_account_id == ^stripe_account_id)
    |> Repo.one()
  end

  @doc """
  Updates KYC record.
  """
  def update_kyc(kyc_id, attrs) do
    case Repo.get(StoreKYC, kyc_id) do
      nil ->
        {:error, :not_found}

      kyc ->
        kyc
        |> StoreKYC.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Updates KYC record by ID (for admin use).
  """
  def update_kyc_by_id(kyc_id, attrs) do
    case Repo.get(StoreKYC, kyc_id) do
      nil ->
        {:error, :not_found}

      kyc ->
        kyc
        |> StoreKYC.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Updates KYC Stripe Connect status.
  """
  def update_kyc_stripe_status(kyc_id, attrs) do
    case Repo.get(StoreKYC, kyc_id) do
      nil ->
        {:error, :not_found}

      kyc ->
        kyc
        |> StoreKYC.changeset(attrs)
        |> Repo.update()
    end
  end


  @doc """
  Gets KYC with store information using string store_id.
  """
  def get_kyc_with_store_by_store_id(store_id_string) do
    case Stores.get_store_by_store_id(store_id_string) do
      nil ->
        nil
      store ->
        get_kyc_with_store(store.id)
    end
  end

  @doc """
  Gets KYC with store information using integer ID.
  """
  def get_kyc_with_store(store_id) do
    StoreKYC
    |> where([k], k.store_id == ^store_id)
    |> preload([:store])
    |> Repo.one()
  end

  @doc """
  Lists all KYC records with store information.
  """
  def list_kyc_records do
    StoreKYC
    |> preload([:store])
    |> Repo.all()
  end

  @doc """
  Lists all KYC records with store and user information for admin interface.
  """
  def list_kyc_records_with_users do
    from(k in StoreKYC,
      join: s in Shomp.Stores.Store, on: k.store_id == s.id,
      join: u in Shomp.Accounts.User, on: s.user_id == u.id,
      order_by: [desc: k.inserted_at],
      select: %{
        id: k.id,
        stripe_account_id: k.stripe_account_id,
        charges_enabled: k.charges_enabled,
        payouts_enabled: k.payouts_enabled,
        onboarding_completed: k.onboarding_completed,
        stripe_individual_info: k.stripe_individual_info,
        country: k.country,
        store: %{
          id: s.id,
          store_id: s.store_id,
          name: s.name,
          slug: s.slug,
          description: s.description
        },
        user: %{
          id: u.id,
          email: u.email,
          username: u.username,
          name: u.name
        },
        inserted_at: k.inserted_at,
        updated_at: k.updated_at
      }
    )
    |> Repo.all()
  end

  @doc """
  Gets Stripe KYC statistics.
  """
  def get_stripe_kyc_stats do
    total = StoreKYC
    |> Repo.aggregate(:count, :id)

    with_stripe_account = StoreKYC
    |> where([k], not is_nil(k.stripe_account_id))
    |> Repo.aggregate(:count, :id)

    charges_enabled = StoreKYC
    |> where([k], k.charges_enabled == true)
    |> Repo.aggregate(:count, :id)

    payouts_enabled = StoreKYC
    |> where([k], k.payouts_enabled == true)
    |> Repo.aggregate(:count, :id)

    fully_verified = StoreKYC
    |> where([k], k.charges_enabled == true and k.payouts_enabled == true and k.onboarding_completed == true)
    |> Repo.aggregate(:count, :id)

    %{
      total: total,
      with_stripe_account: with_stripe_account,
      charges_enabled: charges_enabled,
      payouts_enabled: payouts_enabled,
      fully_verified: fully_verified
    }
  end
end
