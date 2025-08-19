defmodule Shomp.FeatureRequestsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Shomp.FeatureRequests` context.
  """

  @doc """
  Generate a request.
  """
  def request_fixture(user_id, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        description: "some description",
        priority: 42,
        status: "open",
        title: "some title"
      })

    {:ok, request} = Shomp.FeatureRequests.create_request(attrs, user_id)
    request
  end
end
