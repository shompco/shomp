defmodule ShompWeb.Router do
  use ShompWeb, :router

  import ShompWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ShompWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ShompWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/stores", ShompWeb do
    pipe_through :browser

    live "/new", StoreLive.New, :new
    live "/", StoreLive.Index, :index
  end

  scope "/payments", ShompWeb do
    pipe_through :browser

    post "/checkout", PaymentController, :create_checkout
    post "/webhook", PaymentController, :webhook
    get "/success", PaymentController, :success
    get "/cancel", PaymentController, :cancel
  end

  scope "/checkout", ShompWeb do
    pipe_through [:browser, :require_authenticated_user]

    live "/:product_id", CheckoutLive.Show, :show
  end

  ## Authentication routes

  scope "/", ShompWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{ShompWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/dashboard/store", StoreLive.Edit, :edit
      live "/dashboard/products/new", ProductLive.New, :new
      live "/dashboard/products/:id/edit", ProductLive.Edit, :edit
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:shomp, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ShompWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # CATCH-ALL ROUTES - MUST BE LAST!
  # These routes are very broad and will catch anything that doesn't match above
  scope "/", ShompWeb do
    pipe_through :browser

    live "/:slug", StoreLive.Show, :show
    live "/:store_slug/products/:id", ProductLive.Show, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", ShompWeb do
  #   pipe_through :api
  # end

  scope "/", ShompWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{ShompWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
