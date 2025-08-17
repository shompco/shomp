defmodule ShompWeb.PageController do
  use ShompWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
