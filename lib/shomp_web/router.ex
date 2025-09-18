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
      on_mount: [{ShompWeb.UserAuth, :mount_current_scope}, {ShompWeb.CartHook, :default}, {ShompWeb.NotificationHook, :default}, {ShompWeb.NewsletterHook, :default}] do
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

    # SEO routes
    get "/sitemap.xml", SitemapController, :sitemap
    get "/robots.txt", SitemapController, :robots

    live_session :public_with_cart,
      on_mount: [{ShompWeb.UserAuth, :mount_current_scope}, {ShompWeb.CartHook, :default}, {ShompWeb.NotificationHook, :default}] do
      live "/about", AboutLive.Show, :show
      live "/mission", MissionLive.Show, :show
      live "/donations", DonationLive.Show, :show
      live "/donations/quick", DonationLive.Quick, :show
      live "/donations/thank-you", DonationLive.ThankYou, :show
      live "/landing", LandingLive.Show, :show
      live "/categories", CategoryLive.Index, :index
      live "/categories/:slug", CategoryLive.Show, :show
    end
  end

  # Store routes (legacy - keeping for admin)
  scope "/stores", ShompWeb do
    pipe_through :browser

    live_session :stores_with_cart,
      on_mount: [{ShompWeb.UserAuth, :mount_current_scope}, {ShompWeb.CartHook, :default}, {ShompWeb.NotificationHook, :default}, {ShompWeb.NewsletterHook, :default}] do
      live "/", StoreLive.Index, :index
    end
  end

  # Payment routes
  scope "/payments", ShompWeb do
    pipe_through :browser

    post "/checkout", PaymentController, :create_checkout
    get "/custom-donate", PaymentController, :custom_donate
    live "/cancel", PaymentLive.Cancel, :show
  end

  # Webhook route with special pipeline (no CSRF protection)
  scope "/payments", ShompWeb do
    pipe_through :webhook

    post "/webhook", PaymentController, :webhook
  end

  # API routes
  scope "/api", ShompWeb do
    pipe_through :browser

    post "/create-payment-intent", PaymentIntentController, :create
  end

  # Checkout routes
  scope "/checkout", ShompWeb do
    pipe_through :browser

    live_session :checkout,
      on_mount: [{ShompWeb.UserAuth, :mount_current_scope}, {ShompWeb.CartHook, :default}, {ShompWeb.NotificationHook, :default}, {ShompWeb.NewsletterHook, :default}] do
      live "/success", CheckoutLive.Success, :show
      live "/single/:product_id", CheckoutLive.SingleProduct, :show
      live "/processing/:payment_intent_id", CheckoutLive.Processing, :show
      live "/:product_id", CheckoutLive.Show, :show
    end
  end

  # User authentication routes (public)
  scope "/", ShompWeb do
    pipe_through :browser

    live_session :current_user,
      on_mount: [{ShompWeb.UserAuth, :mount_current_scope}, {ShompWeb.CartHook, :default}, {ShompWeb.NotificationHook, :default}, {ShompWeb.NewsletterHook, :default}] do
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
      on_mount: [{ShompWeb.UserAuth, :require_authenticated}, {ShompWeb.CartHook, :default}, {ShompWeb.NotificationHook, :require_authenticated}, {ShompWeb.NewsletterHook, :default}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/users/tier-upgrade", UserLive.TierUpgrade, :new
      live "/users/tier-selection", UserLive.TierSelection, :new
      live "/my/details", ProfileLive.Edit, :edit
      live "/my/products", UserLive.MyProducts, :index

      # Address management
      live "/dashboard/addresses", AddressLive.Index, :index
      live "/dashboard/addresses/new", AddressLive.New, :new
      live "/dashboard/addresses/:id/edit", AddressLive.Edit, :edit
      live "/dashboard/store", StoreLive.Edit, :edit
      live "/dashboard/store/balance", StoreLive.Balance, :show
      live "/dashboard/orders", SellerOrderLive.Index, :index
      live "/dashboard/orders/:immutable_id", SellerOrderLive.Show, :show
      live "/dashboard/orders/universal/:universal_order_id", UniversalOrderLive.Show, :show
      live "/dashboard/purchases", DownloadLive.Purchases, :index
      live "/dashboard/purchases/:universal_order_id", PurchaseDetailsLive.Show, :show

      # Order management (new system)
      live "/orders", OrderLive.Index, :index
      live "/dashboard/orders/:id", OrderLive.Show, :show
      live "/dashboard/products/new", ProductLive.New, :new
      live "/dashboard/products/:id/edit", ProductLive.Edit, :edit
      live "/cart", CartLive.Show, :show
      live "/checkout/cart/:cart_id", CheckoutLive.Cart, :show
      live "/payments/success", PaymentLive.Success, :show

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
      live "/admin/merchant-dashboard", AdminLive.MerchantDashboard, :show
      live "/admin/email-subscriptions", AdminLive.EmailSubscriptions, :show
      live "/admin/users", AdminLive.Users, :show
      live "/admin/stores", AdminLive.Stores, :show
      live "/admin/products", AdminLive.Products, :show
      live "/admin/products/:id/edit", AdminLive.ProductEdit, :edit
      live "/admin/delete-success", AdminLive.DeleteSuccess, :show
      live "/admin/kyc-verification", AdminLive.KYCVerification, :show

      # Admin support routes
      live "/admin/support", AdminLive.SupportDashboard, :index
      live "/admin/support/:ticket_number", SupportLive.Show, :show

      # Universal orders and payment splits
      live "/admin/universal-orders", AdminLive.UniversalOrders, :index
      live "/admin/payment-splits/:universal_order_id", AdminLive.PaymentSplits, :show
      live "/admin/refunds", AdminLive.Refunds, :index

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

  end

  # User profile routes - must come after admin routes to avoid conflicts
  scope "/", ShompWeb do
    pipe_through :browser

    live_session :public_profiles,
      on_mount: [{ShompWeb.UserAuth, :mount_current_scope}, {ShompWeb.CartHook, :default}, {ShompWeb.NotificationHook, :default}, {ShompWeb.NewsletterHook, :default}] do
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

  # Username-based store and product routes - must come AFTER all custom shomp routes
  scope "/", ShompWeb do
    pipe_through :browser

    live_session :public_products_with_cart,
      on_mount: [{ShompWeb.UserAuth, :mount_current_scope}, {ShompWeb.CartHook, :default}, {ShompWeb.NotificationHook, :default}, {ShompWeb.NewsletterHook, :default}] do
      # Username-based store pages (public)
      live "/:username", UserLive.Store, :show_by_username
      live "/:username/:product_slug", ProductLive.Show, :show_by_username_product
    end
  end
end
