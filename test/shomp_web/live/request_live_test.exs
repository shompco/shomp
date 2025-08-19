defmodule ShompWeb.RequestLiveTest do
  use ShompWeb.ConnCase

  import Phoenix.LiveViewTest
  import Shomp.FeatureRequestsFixtures

  @create_attrs %{priority: 42, status: "some status", description: "some description", title: "some title", category: "some category"}
  @update_attrs %{priority: 43, status: "some updated status", description: "some updated description", title: "some updated title", category: "some updated category"}
  @invalid_attrs %{priority: nil, status: nil, description: nil, title: nil, category: nil}

  setup :register_and_log_in_user

  defp create_request(%{scope: scope}) do
    request = request_fixture(scope)

    %{request: request}
  end

  describe "Index" do
    setup [:create_request]

    test "lists all requests", %{conn: conn, request: request} do
      {:ok, _index_live, html} = live(conn, ~p"/requests")

      assert html =~ "Listing Requests"
      assert html =~ request.title
    end

    test "saves new request", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/requests")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Request")
               |> render_click()
               |> follow_redirect(conn, ~p"/requests/new")

      assert render(form_live) =~ "New Request"

      assert form_live
             |> form("#request-form", request: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#request-form", request: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/requests")

      html = render(index_live)
      assert html =~ "Request created successfully"
      assert html =~ "some title"
    end

    test "updates request in listing", %{conn: conn, request: request} do
      {:ok, index_live, _html} = live(conn, ~p"/requests")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#requests-#{request.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/requests/#{request}/edit")

      assert render(form_live) =~ "Edit Request"

      assert form_live
             |> form("#request-form", request: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#request-form", request: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/requests")

      html = render(index_live)
      assert html =~ "Request updated successfully"
      assert html =~ "some updated title"
    end

    test "deletes request in listing", %{conn: conn, request: request} do
      {:ok, index_live, _html} = live(conn, ~p"/requests")

      assert index_live |> element("#requests-#{request.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#requests-#{request.id}")
    end
  end

  describe "Show" do
    setup [:create_request]

    test "displays request", %{conn: conn, request: request} do
      {:ok, _show_live, html} = live(conn, ~p"/requests/#{request}")

      assert html =~ "Show Request"
      assert html =~ request.title
    end

    test "updates request and returns to show", %{conn: conn, request: request} do
      {:ok, show_live, _html} = live(conn, ~p"/requests/#{request}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/requests/#{request}/edit?return_to=show")

      assert render(form_live) =~ "Edit Request"

      assert form_live
             |> form("#request-form", request: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#request-form", request: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/requests/#{request}")

      html = render(show_live)
      assert html =~ "Request updated successfully"
      assert html =~ "some updated title"
    end
  end
end
