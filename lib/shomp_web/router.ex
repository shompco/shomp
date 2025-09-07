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

  pipeline :webhook do
    plug :accepts, ["json"]
    plug :fetch_session
  end

  # Feature Request routes - must come FIRST to avoid conflicts
  scope "/requests", ShompWeb do
    pipe_through :browser

    live_session :feature_requests,
      on_mount: [{ShompWeb.UserAuth, :mount_current_scope}, {ShompWeb.CartHook, :default}, {ShompWeb.NotificationHook, :default}] do
      live "/", RequestLive.Index, :index
      live "/new", RequestLive.Form, :new
      live "/:id", RequestLive.Show, :show
      live "/:id/edit", RequestLive.Form, :edit
    end
  end

  # Root and public routes
  scope "/", ShompWeb do
    pipe_through :browser

    # Root route - must be first to avoid catch-all interception
    get "/", PageController, :home
    
    live_session :public_with_cart,
      on_mount: [{ShompWeb.UserAuth, :mount_current_scope}, {ShompWeb.CartHook, :default}, {ShompWeb.NotificationHook, :default}] do
      live "/about", AboutLive.Show, :show
      live "/donations", DonationLive.Show, :show
      live "/donations/thank-you", DonationLive.ThankYou, :show
      live "/landing", LandingLive.Show, :show
    end
  end

  # Store routes
  scope "/stores", ShompWeb do
    pipe_through :browser

    live_session :stores_with_cart,
      on_mount: [{ShompWeb.UserAuth, :mount_current_scope}, {ShompWeb.CartHook, :default}, {ShompWeb.NotificationHook, :default}] do
      live "/new", StoreLive.New, :new
      live "/", StoreLive.Index, :index
      live "/:slug", StoreLive.Show, :show
    end
  end

  # Payment routes
  scope "/payments", ShompWeb do
    pipe_through :browser

    post "/checkout", PaymentController, :create_checkout
    live "/success", PaymentLive.Success, :show
    live "/cancel", PaymentLive.Cancel, :show
  end

  # Webhook route with special pipeline (no CSRF protection)
  scope "/payments", ShompWeb do
    pipe_through :webhook

    post "/webhook", PaymentController, :webhook
  end

  # Checkout routes
  scope "/checkout", ShompWeb do
    pipe_through [:browser, :require_authenticated_user]

    live "/:product_id", CheckoutLive.Show, :show
  end

  # User authentication routes (public)
  scope "/", ShompWeb do
    pipe_through :browser

    live_session :current_user,
      on_mount: [{ShompWeb.UserAuth, :mount_current_scope}, {ShompWeb.CartHook, :default}, {ShompWeb.NotificationHook, :default}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end

  ## Authenticated routes

  scope "/", ShompWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{ShompWeb.UserAuth, :require_authenticated}, {ShompWeb.CartHook, :default}, {ShompWeb.NotificationHook, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/users/tier-upgrade", UserLive.TierUpgrade, :new
      live "/users/tier-selection", UserLive.TierSelection, :new
      live "/users/profile", ProfileLive.Edit, :edit
      live "/my/stores", StoreLive.MyStores, :index
      
      # Address management
      live "/dashboard/addresses", AddressLive.Index, :index
      live "/dashboard/addresses/new", AddressLive.New, :new
      live "/dashboard/addresses/:id/edit", AddressLive.Edit, :edit
      live "/dashboard/store", StoreLive.Edit, :edit
      live "/dashboard/store/balance", StoreLive.Balance, :show
      live "/dashboard/store/kyc", StoreLive.KYC, :show
      live "/dashboard/orders", StoreLive.Orders, :index
      live "/dashboard/products/new", ProductLive.New, :new
      live "/dashboard/products/:id/edit", ProductLive.Edit, :edit
      live "/cart", CartLive.Show, :show
      live "/checkout/cart/:cart_id", CheckoutLive.Cart, :show
      
      # Support system routes
      live "/support", SupportLive.Index, :index
      live "/support/:ticket_number", SupportLive.Show, :show
      
      # Email preferences
      live "/email-preferences", UserLive.EmailPreferences, :index
      
      # Notification preferences and inbox
      live "/notification-preferences", UserLive.NotificationPreferences, :index
      live "/notifications", UserLive.Notifications, :index
      
      # Admin routes
      live "/admin", AdminLive.Dashboard, :show
      live "/admin/email-subscriptions", AdminLive.EmailSubscriptions, :show
      live "/admin/users", AdminLive.Users, :show
      live "/admin/stores", AdminLive.Stores, :show
      live "/admin/products", AdminLive.Products, :show
      live "/admin/products/:id/edit", AdminLive.ProductEdit, :edit
      live "/admin/kyc-verification", AdminLive.KYCVerification, :show
      
      # Admin support routes
      live "/admin/support", AdminLive.SupportDashboard, :index
      live "/admin/support/:ticket_number", SupportLive.Show, :show
      
      # Admin order routes
      get "/admin/orders", OrderController, :index
      live "/admin/orders/:immutable_id", AdminLive.OrderShow, :show
    end

    post "/users/update-password", UserSessionController, :update_password
    
    # Download routes
    get "/downloads/:token", DownloadController, :show
    get "/downloads/:token/download", DownloadController, :download
    get "/purchases", DownloadController, :purchases
    
    # Order routes
    get "/orders", OrderController, :index
    get "/orders/:id", OrderController, :show
    
    # Review routes
    get "/reviews", ReviewController, :index
    get "/reviews/new", ReviewController, :new
    post "/reviews", ReviewController, :create
    get "/reviews/:id/edit", ReviewController, :edit
    put "/reviews/:id", ReviewController, :update
    delete "/reviews/:id", ReviewController, :delete
    post "/reviews/:review_id/vote", ReviewController, :vote
    
    # Secure KYC image access
    get "/kyc-images/:filename", KYCImageController, :show
  end

  # User profile routes - must come after admin routes to avoid conflicts
  scope "/", ShompWeb do
    pipe_through :browser

    live_session :public_profiles,
      on_mount: [{ShompWeb.UserAuth, :mount_current_scope}, {ShompWeb.CartHook, :default}, {ShompWeb.NotificationHook, :default}] do
      live "/:username", ProfileLive.Show, :show
    end
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

  # Product and category routes - specific patterns
  scope "/", ShompWeb do
    pipe_through :browser

    live_session :public_products_with_cart,
      on_mount: [{ShompWeb.UserAuth, :mount_current_scope}, {ShompWeb.CartHook, :default}, {ShompWeb.NotificationHook, :default}] do
      # Product routes - new structure with /stores/ prefix
      live "/stores/:store_slug/products/:product_slug", ProductLive.Show, :show_by_store_product_slug
      
      # Custom category product routes
      live "/stores/:store_slug/:category_slug/:product_slug", ProductLive.Show, :show_by_slug
      
      # Store category route
      live "/stores/:store_slug/:category_slug", StoreLive.Show, :show_category
    end

    # Store-specific review routes
    get "/stores/:store_slug/products/:product_id/reviews", ReviewController, :index
    get "/stores/:store_slug/products/:product_id/reviews/new", ReviewController, :new
    post "/stores/:store_slug/products/:product_id/reviews", ReviewController, :create
    get "/stores/:store_slug/products/:product_id/reviews/:id/edit", ReviewController, :edit
    put "/stores/:store_slug/products/:product_id/reviews/:id", ReviewController, :update
    delete "/stores/:store_slug/products/:product_id/reviews/:id", ReviewController, :delete
  end
end
