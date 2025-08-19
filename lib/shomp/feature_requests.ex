defmodule Shomp.FeatureRequests do
  @moduledoc """
  The FeatureRequests context for managing feature requests, votes, and comments.
  """

  import Ecto.Query, warn: false
  alias Shomp.Repo
  alias Shomp.FeatureRequests.{Request, Vote, Comment}

  @doc """
  Gets a single feature request by ID.
  """
  def get_request!(id) do
    Request
    |> Repo.get!(id)
    |> Repo.preload([:user, votes: :user, comments: :user])
  end

  @doc """
  Lists all feature requests.
  """
  def list_requests(opts \\ []) do
    Request
    |> filter_by_status(opts[:status])
    |> order_by_priority(opts[:order])
    |> Repo.all()
    |> Repo.preload([:user, votes: :user, comments: :user])
  end

  @doc """
  Lists feature requests for a specific user.
  """
  def list_user_requests(user_id) do
    Request
    |> where([r], r.user_id == ^user_id)
    |> order_by([r], [desc: r.inserted_at])
    |> Repo.all()
    |> Repo.preload([:user, votes: :user, comments: :user])
  end

  @doc """
  Creates a new feature request.
  """
  def create_request(attrs \\ %{}, user_id) do
    %Request{}
    |> Request.create_changeset(attrs, user_id)
    |> Repo.insert()
  end

  @doc """
  Updates a feature request.
  """
  def update_request(%Request{} = request, attrs) do
    request
    |> Request.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a feature request.
  """
  def delete_request(%Request{} = request) do
    Repo.delete(request)
  end

  @doc """
  Gets a single vote by ID.
  """
  def get_vote!(id) do
    Repo.get!(Vote, id)
  end

  @doc """
  Gets a vote by request and user.
  """
  def get_vote_by_request_and_user(request_id, user_id) do
    Vote
    |> where([v], v.request_id == ^request_id and v.user_id == ^user_id)
    |> Repo.one()
  end

  @doc """
  Creates a new vote.
  """
  def create_vote(attrs \\ %{}, user_id) do
    %Vote{}
    |> Vote.create_changeset(attrs, user_id)
    |> Repo.insert()
  end

  @doc """
  Updates a vote.
  """
  def update_vote(%Vote{} = vote, attrs) do
    vote
    |> Vote.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a vote.
  """
  def delete_vote(%Vote{} = vote) do
    Repo.delete(vote)
  end

  @doc """
  Votes on a feature request (creates or updates existing vote).
  """
  def vote_request(request_id, user_id, weight) do
    case get_vote_by_request_and_user(request_id, user_id) do
      nil ->
        # Create new vote
        create_vote(%{request_id: request_id, weight: weight}, user_id)
      
      existing_vote ->
        if existing_vote.weight == weight do
          # Same weight, remove vote
          delete_vote(existing_vote)
        else
          # Update weight
          update_vote(existing_vote, %{weight: weight})
        end
    end
  end

  @doc """
  Gets the total vote weight for a request.
  """
  def get_request_vote_total(request_id) do
    Vote
    |> where([v], v.request_id == ^request_id)
    |> select([v], sum(v.weight))
    |> Repo.one()
    |> case do
      nil -> 0
      total -> total
    end
  end

  @doc """
  Gets a single comment by ID.
  """
  def get_comment!(id) do
    Repo.get!(Comment, id)
  end

  @doc """
  Lists comments for a feature request.
  """
  def list_request_comments(request_id) do
    Comment
    |> where([c], c.request_id == ^request_id)
    |> order_by([c], [asc: c.created_at])
    |> Repo.all()
    |> Repo.preload(:user)
  end

  @doc """
  Creates a new comment.
  """
  def create_comment(attrs \\ %{}, user_id) do
    %Comment{}
    |> Comment.create_changeset(attrs, user_id)
    |> Repo.insert()
  end

  @doc """
  Updates a comment.
  """
  def update_comment(%Comment{} = comment, attrs) do
    comment
    |> Comment.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a comment.
  """
  def delete_comment(%Comment{} = comment) do
    Repo.delete(comment)
  end

  @doc """
  Searches feature requests by title and description.
  """
  def search_requests(query) do
    search_term = "%#{query}%"
    
    Request
    |> where([r], ilike(r.title, ^search_term) or ilike(r.description, ^search_term))
    |> order_by([r], [desc: r.inserted_at])
    |> Repo.all()
    |> Repo.preload([:user, votes: :user, comments: :user])
  end

  @doc """
  Merges duplicate feature requests.
  """
  def merge_requests(source_request_id, target_request_id) do
    # Move all votes from source to target
    Vote
    |> where([v], v.request_id == ^source_request_id)
    |> Repo.update_all(set: [request_id: target_request_id])
    
    # Move all comments from source to target
    Comment
    |> where([c], c.request_id == ^source_request_id)
    |> Repo.update_all(set: [request_id: target_request_id])
    
    # Delete the source request
    source_request = Repo.get!(Request, source_request_id)
    delete_request(source_request)
    
    {:ok, :merged}
  end

  # Private functions for filtering and ordering

  defp filter_by_status(query, nil), do: query
  defp filter_by_status(query, status) do
    query |> where([r], r.status == ^status)
  end

  defp order_by_priority(query, "priority") do
    query |> order_by([r], [desc: r.priority, desc: r.inserted_at])
  end
  defp order_by_priority(query, "votes") do
    query |> order_by([r], [desc: fragment("(SELECT COALESCE(SUM(v.weight), 0) FROM votes v WHERE v.request_id = ?)", r.id), desc: r.inserted_at])
  end
  defp order_by_priority(query, _) do
    query |> order_by([r], [desc: r.inserted_at])
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking request changes.
  """
  def change_request(%Request{} = request, attrs \\ %{}) do
    Request.changeset(request, attrs)
  end
end
