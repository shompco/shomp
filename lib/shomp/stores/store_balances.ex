defmodule Shomp.Stores.StoreBalances do
  @moduledoc """
  The StoreBalances context for managing store earnings and payouts.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.Stores.StoreBalance
  alias Shomp.Stores

  @doc """
  Gets or creates a store balance for a store using string store_id.
  """
  def get_or_create_store_balance_by_store_id(store_id_string) do
    case Stores.get_store_by_store_id(store_id_string) do
      nil ->
        {:error, :store_not_found}
      store ->
        get_or_create_store_balance(store.id)
    end
  end

  @doc """
  Gets a store balance by string store_id.
  """
  def get_store_balance_by_store_id(store_id_string) do
    case Stores.get_store_by_store_id(store_id_string) do
      nil ->
        nil
      store ->
        get_store_balance(store.id)
    end
  end

  @doc """
  Gets or creates a store balance for a store using integer ID.
  """
  def get_or_create_store_balance(store_id) do
    case get_store_balance(store_id) do
      nil ->
        create_store_balance(%{store_id: store_id})
      store_balance ->
        {:ok, store_balance}
    end
  end

  @doc """
  Gets a store balance by store ID.
  """
  def get_store_balance(store_id) do
    StoreBalance
    |> where([sb], sb.store_id == ^store_id)
    |> Repo.one()
  end

  @doc """
  Creates a new store balance.
  """
  def create_store_balance(attrs \\ %{}) do
    %StoreBalance{}
    |> StoreBalance.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a store balance when a sale is made using string store_id.
  """
  def add_sale_by_store_id(store_id_string, sale_amount) do
    case Stores.get_store_by_store_id(store_id_string) do
      nil ->
        {:error, :store_not_found}
      store ->
        add_sale(store.id, sale_amount)
    end
  end

  @doc """
  Updates a store balance when a sale is made using integer ID.
  """
  def add_sale(store_id, sale_amount) do
    case get_or_create_store_balance(store_id) do
      {:ok, store_balance} ->
        store_balance
        |> StoreBalance.add_sale_changeset(sale_amount)
        |> Repo.update()
      
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Processes a payout for a store using string store_id.
  """
  def process_payout_by_store_id(store_id_string, payout_amount) do
    case Stores.get_store_by_store_id(store_id_string) do
      nil ->
        {:error, :store_not_found}
      store ->
        process_payout(store.id, payout_amount)
    end
  end

  @doc """
  Processes a payout for a store using integer ID.
  """
  def process_payout(store_id, payout_amount) do
    case get_store_balance(store_id) do
      nil ->
        {:error, :store_balance_not_found}
      
      store_balance ->
        if StoreBalance.eligible_for_payout?(store_balance) do
          if Decimal.gte?(store_balance.pending_balance, payout_amount) do
            store_balance
            |> StoreBalance.payout_changeset(payout_amount)
            |> Repo.update()
          else
            {:error, :insufficient_balance}
          end
        else
          {:error, :not_eligible_for_payout}
        end
    end
  end

  @doc """
  Gets all stores eligible for payouts.
  Note: This function is deprecated. Use Stripe Connect status checks instead.
  """
  def list_eligible_for_payout do
    StoreBalance
    |> where([sb], sb.pending_balance > 0)
    |> preload([:store])
    |> Repo.all()
  end

  @doc """
  Gets payout statistics.
  Note: This function is deprecated. Use Stripe Connect status checks instead.
  """
  def get_payout_stats do
    total_pending = StoreBalance
    |> select([sb], sum(sb.pending_balance))
    |> Repo.one()
    |> case do
      nil -> Decimal.new(0)
      total -> total
    end

    total_paid_out = StoreBalance
    |> select([sb], sum(sb.paid_out_balance))
    |> Repo.one()
    |> case do
      nil -> Decimal.new(0)
      total -> total
    end

    eligible_stores = StoreBalance
    |> where([sb], sb.pending_balance > 0)
    |> Repo.aggregate(:count, :id)

    %{
      total_pending: total_pending,
      total_paid_out: total_paid_out,
      eligible_stores: eligible_stores
    }
  end

  @doc """
  Gets store balance with store information using string store_id.
  """
  def get_store_balance_with_store_by_store_id(store_id_string) do
    case Stores.get_store_by_store_id(store_id_string) do
      nil ->
        nil
      store ->
        get_store_balance_with_store(store.id)
    end
  end

  @doc """
  Gets store balance with store information using integer ID.
  """
  def get_store_balance_with_store(store_id) do
    StoreBalance
    |> where([sb], sb.store_id == ^store_id)
    |> preload([:store])
    |> Repo.one()
  end

  @doc """
  Lists all store balances with store information.
  """
  def list_store_balances do
    StoreBalance
    |> preload([:store])
    |> Repo.all()
  end

end
