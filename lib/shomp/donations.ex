defmodule Shomp.Donations do
  @moduledoc """
  Handles donation goals and donations.
  """

  alias Shomp.Donations.{DonationGoal, Donation}
  alias Shomp.Repo
  import Ecto.Query

  @doc """
  Gets the current active donation goal.
  """
  def get_current_goal do
    from(g in DonationGoal, where: g.status == "active")
    |> Repo.one()
  end

  @doc """
  Creates or updates the current donation goal.
  """
  def set_goal(attrs) do
    case get_current_goal() do
      nil -> create_goal(attrs)
      goal -> update_goal(goal, attrs)
    end
  end

  @doc """
  Resets the current goal progress to zero.
  """
  def reset_goal_progress do
    case get_current_goal() do
      nil -> {:error, :no_goal}
      goal -> update_goal(goal, %{current_amount: 0.0})
    end
  end

  @doc """
  Records a new donation.
  """
  def record_donation(attrs) do
    with {:ok, donation} <- create_donation(attrs),
         :ok <- update_goal_amount(donation.donation_goal_id, donation.amount) do
      {:ok, donation}
    end
  end

  @doc """
  Gets donor count for current goal.
  """
  def get_donor_count do
    case get_current_goal() do
      nil -> 0
      goal ->
        from(d in Donation,
          where: d.donation_goal_id == ^goal.id and d.status == "completed",
          select: count(d.id)
        )
        |> Repo.one()
    end
  end

  @doc """
  Gets recent public donations for toaster notifications.
  Returns donations sorted by most recent first.
  """
  def get_recent_public_donations(limit \\ 10) do
    case get_current_goal() do
      nil -> []
      goal ->
        from(d in Donation,
          where: d.donation_goal_id == ^goal.id
                 and d.status == "completed"
                 and d.is_public == true,
          order_by: [desc: d.inserted_at],
          limit: ^limit,
          select: %{
            id: d.id,
            amount: d.amount,
            donor_name: d.donor_name,
            is_anonymous: d.is_anonymous,
            message: d.message,
            inserted_at: d.inserted_at
          }
        )
        |> Repo.all()
    end
  end

  @doc """
  Gets the most recent donation for immediate toaster notification.
  """
  def get_latest_donation do
    case get_current_goal() do
      nil -> nil
      goal ->
        from(d in Donation,
          where: d.donation_goal_id == ^goal.id
                 and d.status == "completed"
                 and d.is_public == true,
          order_by: [desc: d.inserted_at],
          limit: 1,
          select: %{
            id: d.id,
            amount: d.amount,
            donor_name: d.donor_name,
            is_anonymous: d.is_anonymous,
            message: d.message,
            inserted_at: d.inserted_at
          }
        )
        |> Repo.one()
    end
  end

  @doc """
  Gets donation statistics for the current goal.
  """
  def get_donation_stats do
    case get_current_goal() do
      nil -> %{total_donations: 0, total_amount: 0, average_donation: 0}
      goal ->
        stats = from(d in Donation,
          where: d.donation_goal_id == ^goal.id and d.status == "completed",
          select: %{
            count: count(d.id),
            total: sum(d.amount),
            average: avg(d.amount)
          }
        )
        |> Repo.one()

        %{
          total_donations: stats.count || 0,
          total_amount: stats.total || Decimal.new(0),
          average_donation: stats.average || Decimal.new(0)
        }
    end
  end

  defp create_goal(attrs) do
    %DonationGoal{}
    |> DonationGoal.changeset(attrs)
    |> Repo.insert()
  end

  defp update_goal(goal, attrs) do
    goal
    |> DonationGoal.changeset(attrs)
    |> Repo.update()
  end

  defp create_donation(attrs) do
    %Donation{}
    |> Donation.changeset(attrs)
    |> Repo.insert()
  end

  defp update_goal_amount(goal_id, amount) do
    goal = Repo.get(DonationGoal, goal_id)
    if goal do
      new_amount = Decimal.add(goal.current_amount, amount)
      update_goal(goal, %{current_amount: new_amount})
    else
      :ok
    end
  end
end
