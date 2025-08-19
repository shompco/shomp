defmodule Shomp.FeatureRequestsTest do
  use Shomp.DataCase

  alias Shomp.FeatureRequests

  describe "requests" do
    alias Shomp.FeatureRequests.Request

    import Shomp.AccountsFixtures, only: [user_scope_fixture: 0]
    import Shomp.FeatureRequestsFixtures

    @invalid_attrs %{priority: nil, status: nil, description: nil, title: nil, category: nil}

    test "list_requests/1 returns all scoped requests" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      request = request_fixture(scope)
      other_request = request_fixture(other_scope)
      assert FeatureRequests.list_requests(scope) == [request]
      assert FeatureRequests.list_requests(other_scope) == [other_request]
    end

    test "get_request!/2 returns the request with given id" do
      scope = user_scope_fixture()
      request = request_fixture(scope)
      other_scope = user_scope_fixture()
      assert FeatureRequests.get_request!(scope, request.id) == request
      assert_raise Ecto.NoResultsError, fn -> FeatureRequests.get_request!(other_scope, request.id) end
    end

    test "create_request/2 with valid data creates a request" do
      valid_attrs = %{priority: 42, status: "some status", description: "some description", title: "some title", category: "some category"}
      scope = user_scope_fixture()

      assert {:ok, %Request{} = request} = FeatureRequests.create_request(scope, valid_attrs)
      assert request.priority == 42
      assert request.status == "some status"
      assert request.description == "some description"
      assert request.title == "some title"
      assert request.category == "some category"
      assert request.user_id == scope.user.id
    end

    test "create_request/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = FeatureRequests.create_request(scope, @invalid_attrs)
    end

    test "update_request/3 with valid data updates the request" do
      scope = user_scope_fixture()
      request = request_fixture(scope)
      update_attrs = %{priority: 43, status: "some updated status", description: "some updated description", title: "some updated title", category: "some updated category"}

      assert {:ok, %Request{} = request} = FeatureRequests.update_request(scope, request, update_attrs)
      assert request.priority == 43
      assert request.status == "some updated status"
      assert request.description == "some updated description"
      assert request.title == "some updated title"
      assert request.category == "some updated category"
    end

    test "update_request/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      request = request_fixture(scope)

      assert_raise MatchError, fn ->
        FeatureRequests.update_request(other_scope, request, %{})
      end
    end

    test "update_request/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      request = request_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = FeatureRequests.update_request(scope, request, @invalid_attrs)
      assert request == FeatureRequests.get_request!(scope, request.id)
    end

    test "delete_request/2 deletes the request" do
      scope = user_scope_fixture()
      request = request_fixture(scope)
      assert {:ok, %Request{}} = FeatureRequests.delete_request(scope, request)
      assert_raise Ecto.NoResultsError, fn -> FeatureRequests.get_request!(scope, request.id) end
    end

    test "delete_request/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      request = request_fixture(scope)
      assert_raise MatchError, fn -> FeatureRequests.delete_request(other_scope, request) end
    end

    test "change_request/2 returns a request changeset" do
      scope = user_scope_fixture()
      request = request_fixture(scope)
      assert %Ecto.Changeset{} = FeatureRequests.change_request(scope, request)
    end
  end
end
