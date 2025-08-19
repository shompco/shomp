defmodule Shomp.FeatureRequestsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Shomp.FeatureRequests` context.
  """

  @doc """
  Generate a request.
  """
  def request_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        category: "some category",
        description: "some description",
        priority: 42,
        status: "some status",
        title: "some title"
      })

    {:ok, request} = Shomp.FeatureRequests.create_request(scope, attrs)
    request
  end
end
