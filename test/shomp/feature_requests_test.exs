defmodule Shomp.FeatureRequestsTest do
  use Shomp.DataCase

  alias Shomp.FeatureRequests
  alias Shomp.FeatureRequests.{Request, Vote, Comment}

  import Shomp.FeatureRequestsFixtures
  import Shomp.AccountsFixtures

  describe "requests" do
    alias Shomp.FeatureRequests.Request

    test "list_requests/0 returns all requests" do
      user = user_fixture()
      request = request_fixture(user.id)
      assert FeatureRequests.list_requests() == [request]
    end

    test "get_request!/1 returns the request with given id" do
      user = user_fixture()
      request = request_fixture(user.id)
      assert FeatureRequests.get_request!(request.id) == request
    end

    test "create_request/2 with valid data creates a request" do
      user = user_fixture()
      valid_attrs = %{title: "some title", description: "some description", status: "open", priority: 42}

      assert {:ok, %Request{} = request} = FeatureRequests.create_request(valid_attrs, user.id)
      assert request.title == "some title"
      assert request.description == "some description"
      assert request.status == "open"
      assert request.priority == 42
    end

    test "create_request/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = FeatureRequests.create_request(%{title: nil}, user.id)
    end

    test "update_request/2 with valid data updates the request" do
      user = user_fixture()
      request = request_fixture(user.id)
      update_attrs = %{title: "some updated title", description: "some updated description", status: "open", priority: 43}

      assert {:ok, %Request{} = request} = FeatureRequests.update_request(request, update_attrs)
      assert request.title == "some updated title"
      assert request.description == "some updated description"
      assert request.priority == 43
    end

    test "update_request/2 with invalid data returns error changeset" do
      user = user_fixture()
      request = request_fixture(user.id)
      assert {:error, %Ecto.Changeset{}} = FeatureRequests.update_request(request, %{title: nil})
      assert request == FeatureRequests.get_request!(request.id)
    end

    test "delete_request/1 deletes the request" do
      user = user_fixture()
      request = request_fixture(user.id)
      assert {:ok, %Request{}} = FeatureRequests.delete_request(request)
      assert_raise Ecto.NoResultsError, fn -> FeatureRequests.get_request!(request.id) end
    end

    test "change_request/1 returns a request changeset" do
      user = user_fixture()
      request = request_fixture(user.id)
      assert %Ecto.Changeset{} = FeatureRequests.change_request(request)
    end
  end

  describe "votes" do
    alias Shomp.FeatureRequests.Vote

    test "create_vote/2 with valid data creates a vote" do
      user = user_fixture()
      request = request_fixture(user.id)
      valid_attrs = %{request_id: request.id, weight: 1}

      assert {:ok, %Vote{} = vote} = FeatureRequests.create_vote(valid_attrs, user.id)
      assert vote.weight == 1
      assert vote.request_id == request.id
      assert vote.user_id == user.id
    end

    test "create_vote/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = FeatureRequests.create_vote(%{weight: nil}, user.id)
    end

    test "vote_request/3 creates a new vote when none exists" do
      user = user_fixture()
      request = request_fixture(user.id)

      assert {:ok, %Vote{} = vote} = FeatureRequests.vote_request(request.id, user.id, 1)
      assert vote.weight == 1
      assert vote.request_id == request.id
      assert vote.user_id == user.id
    end

    test "vote_request/3 updates existing vote when weight is different" do
      user = user_fixture()
      request = request_fixture(user.id)

      # Create initial vote
      {:ok, _vote} = FeatureRequests.vote_request(request.id, user.id, 1)
      
      # Update vote to different weight
      assert {:ok, %Vote{} = updated_vote} = FeatureRequests.vote_request(request.id, user.id, -1)
      assert updated_vote.weight == -1
    end

    test "vote_request/3 removes vote when same weight is voted again" do
      user = user_fixture()
      request = request_fixture(user.id)

      # Create initial vote
      {:ok, _vote} = FeatureRequests.vote_request(request.id, user.id, 1)
      
      # Remove vote by voting same weight again
      assert {:ok, _} = FeatureRequests.vote_request(request.id, user.id, 1)
      
      # Verify vote was removed
      assert FeatureRequests.get_vote_by_request_and_user(request.id, user.id) == nil
    end

    test "get_request_vote_total/1 returns correct total" do
      user1 = user_fixture()
      user2 = user_fixture()
      request = request_fixture(user1.id)

      # User 1 upvotes
      {:ok, _} = FeatureRequests.vote_request(request.id, user1.id, 1)
      
      # User 2 downvotes
      {:ok, _} = FeatureRequests.vote_request(request.id, user2.id, -1)
      
      # Total should be 0 (1 + -1)
      assert FeatureRequests.get_request_vote_total(request.id) == 0
    end

    test "get_vote_by_request_and_user/2 returns correct vote" do
      user = user_fixture()
      request = request_fixture(user.id)
      {:ok, vote} = FeatureRequests.vote_request(request.id, user.id, 1)

      assert FeatureRequests.get_vote_by_request_and_user(request.id, user.id) == vote
    end
  end

  describe "comments" do
    alias Shomp.FeatureRequests.Comment

    test "create_comment/2 with valid data creates a comment" do
      user = user_fixture()
      request = request_fixture(user.id)
      valid_attrs = %{request_id: request.id, content: "some content"}

      assert {:ok, %Comment{} = comment} = FeatureRequests.create_comment(valid_attrs, user.id)
      assert comment.content == "some content"
      assert comment.request_id == request.id
      assert comment.user_id == user.id
    end

    test "create_comment/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = FeatureRequests.create_comment(%{content: nil}, user.id)
    end

    test "update_comment/2 with valid data updates the comment" do
      user = user_fixture()
      request = request_fixture(user.id)
      comment = comment_fixture(request.id, user.id)
      update_attrs = %{content: "some updated content"}

      assert {:ok, %Comment{} = comment} = FeatureRequests.update_comment(comment, update_attrs)
      assert comment.content == "some updated content"
    end

    test "update_comment/2 with invalid data returns error changeset" do
      user = user_fixture()
      request = request_fixture(user.id)
      comment = comment_fixture(request.id, user.id)
      assert {:error, %Ecto.Changeset{}} = FeatureRequests.update_comment(comment, %{content: nil})
      assert comment == FeatureRequests.get_comment!(comment.id)
    end

    test "delete_comment/1 deletes the comment" do
      user = user_fixture()
      request = request_fixture(user.id)
      comment = comment_fixture(request.id, user.id)
      assert {:ok, %Comment{}} = FeatureRequests.delete_comment(comment)
      assert_raise Ecto.NoResultsError, fn -> FeatureRequests.get_comment!(comment.id) end
    end

    test "list_request_comments/1 returns comments for request" do
      user = user_fixture()
      request = request_fixture(user.id)
      comment = comment_fixture(request.id, user.id)
      assert FeatureRequests.list_request_comments(request.id) == [comment]
    end
  end

  defp comment_fixture(request_id, user_id, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{content: "some content", request_id: request_id})
    {:ok, comment} = FeatureRequests.create_comment(attrs, user_id)
    comment
  end
end
