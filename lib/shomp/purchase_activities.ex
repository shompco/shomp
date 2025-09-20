defmodule Shomp.PurchaseActivities do
  @moduledoc """
  Handles purchase activity tracking and display for toaster notifications.
  """

  alias Shomp.PurchaseActivities.PurchaseActivity
  alias Shomp.Repo
  import Ecto.Query

  @doc """
  Records a new purchase activity.
  """
  def record_purchase(order, product, buyer) do
    # Only record if buyer hasn't opted out
    if buyer.show_purchase_activity != false do
      activity_attrs = %{
        order_id: order.id,
        product_id: product.id,
        buyer_id: buyer.id,
        buyer_initials: get_buyer_initials(buyer),
        buyer_location: get_buyer_location(buyer),
        product_title: product.title,
        amount: order.total_amount,
        is_public: buyer.show_purchase_activity != false
      }

      %PurchaseActivity{}
      |> PurchaseActivity.changeset(activity_attrs)
      |> Repo.insert()
    end
  end

  @doc """
  Gets recent public purchase activities for toaster display.
  """
  def get_recent_activities(limit \\ 10) do
    from(pa in PurchaseActivity,
      where: pa.is_public == true,
      order_by: [desc: pa.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Gets activities that haven't been displayed yet.
  """
  def get_unshown_activities(limit \\ 5) do
    from(pa in PurchaseActivity,
      where: pa.is_public == true and is_nil(pa.displayed_at),
      order_by: [asc: pa.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Marks an activity as displayed.
  """
  def mark_as_displayed(activity) do
    activity
    |> PurchaseActivity.changeset(%{
      displayed_at: DateTime.utc_now(),
      display_count: activity.display_count + 1
    })
    |> Repo.update()
  end

  @doc """
  Cleans up old activities (older than 48 hours).
  """
  def cleanup_old_activities do
    cutoff_time = DateTime.add(DateTime.utc_now(), -48, :hour)
    
    from(pa in PurchaseActivity,
      where: pa.inserted_at < ^cutoff_time
    )
    |> Repo.delete_all()
  end

  defp get_buyer_initials(buyer) do
    if buyer.name do
      buyer.name
      |> String.split()
      |> Enum.map(&String.first/1)
      |> Enum.join("")
      |> String.upcase()
    else
      String.first(buyer.email) |> String.upcase()
    end
  end

  defp get_buyer_location(buyer) do
    # This would come from user profile or order shipping address
    # For now, return a placeholder or get from user's location setting
    buyer.location || "Unknown Location"
  end
end
