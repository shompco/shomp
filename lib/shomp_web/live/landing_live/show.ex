defmodule ShompWeb.LandingLive.Show do
  use ShompWeb, :live_view
  alias Shomp.EmailSubscriptions

  @page_title "About Shomp - The Nonprofit Marketplace"

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: @page_title, subscribed: false)}
  end

  def handle_event("subscribe", %{"email" => email}, socket) do
    case EmailSubscriptions.create_email_subscription(%{email: email, source: "landing_page"}) do
      {:ok, _subscription} ->
        {:noreply, 
         socket 
         |> put_flash(:info, "Thank you for joining the movement! We'll keep you updated on our mission to empower creators.")
         |> assign(:subscribed, true)}
      
      {:error, changeset} ->
        error_message = get_error_message(changeset)
        {:noreply, socket |> put_flash(:error, error_message)}
    end
  end

  defp get_error_message(changeset) do
    case changeset.errors do
      [email: {"has already been taken", _}] -> 
        "This email is already subscribed. Thank you for your interest!"
      _ -> 
        "There was an error processing your subscription. Please try again."
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />
    
    <.hero_section subscribed={@subscribed} />
    <.problem_section />
    <.solution_section />
    <.how_it_works_section />
    <.product_categories_section />
    <.values_section />
    <.technical_section />
    <.cta_section subscribed={@subscribed} />
    <.faq_section />
    <.final_cta_section subscribed={@subscribed} />
    
    <!-- Admin Floating Action Button -->
    <%= if assigns[:current_scope] && @current_scope.user && @current_scope.user.role == "admin" do %>
      <div class="fixed bottom-6 right-6 z-50">
        <div class="dropdown dropdown-top dropdown-end">
          <div tabindex="0" role="button" class="btn btn-circle btn-error btn-lg shadow-lg">
            🛠️
          </div>
          <ul tabindex="0" class="dropdown-content z-[1] menu p-2 shadow-xl bg-base-100 rounded-box w-52 mb-2">
            <li>
              <a href="/admin" class="text-error">
                🛠️ Admin Dashboard
              </a>
            </li>
            <li>
              <a href="/admin/email-subscriptions" class="text-error">
                📧 Email Subscriptions
              </a>
            </li>
            <li>
              <a href="/" class="text-primary">
                🏠 Back to Home
              </a>
            </li>
          </ul>
        </div>
      </div>
    <% end %>
    """
  end

  defp hero_section(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-primary/5 via-secondary/5 to-accent/5 flex items-center">
      <div class="container mx-auto px-4 text-center">
        <div class="max-w-4xl mx-auto">
          <.brand_header />
          <.mission_statement subscribed={@subscribed} />
          <.social_proof />
        </div>
      </div>
    </div>
    """
  end

  defp brand_header(assigns) do
    ~H"""
    <div class="mb-8">
      <h1 class="text-6xl md:text-8xl font-bold text-primary mb-4">Shomp</h1>
      <div class="text-2xl md:text-3xl font-light text-base-content/70 mb-6">
        The nonprofit marketplace where creators keep 
        <span class="font-bold text-success">100% of their earnings</span>
      </div>
    </div>
    """
  end

  defp mission_statement(assigns) do
    ~H"""
    <div class="bg-base-100/80 backdrop-blur-sm rounded-2xl p-8 mb-12 shadow-xl border border-base-300">
      <h2 class="text-3xl md:text-4xl font-bold mb-6 text-base-content">
        No Platform Fees. No Corporate Middlemen. Just Creators & Community.
      </h2>
      <p class="text-xl text-base-content/70 leading-relaxed mb-8">
        Shomp is a 501c3 nonprofit e-commerce platform built by creators, for creators. 
        We believe artists should be rewarded for their work, not exploited by corporate fees.
      </p>
      
      <.email_signup_form subscribed={@subscribed} />
    </div>
    """
  end

  defp email_signup_form(assigns) do
    ~H"""
    <div class="max-w-md mx-auto">
      <%= if @subscribed do %>
        <.success_message />
      <% else %>
        <.signup_form />
      <% end %>
    </div>
    """
  end

  defp success_message(assigns) do
    ~H"""
    <div class="bg-success/20 border border-success/30 rounded-lg p-6 text-center">
      <div class="text-4xl mb-3">🎉</div>
      <h3 class="text-xl font-bold text-success mb-2">Welcome to the Movement!</h3>
      <p class="text-success/80">
        We'll keep you updated on our mission to empower creators worldwide.
      </p>
    </div>
    """
  end

  defp signup_form(assigns) do
    ~H"""
    <form phx-submit="subscribe" class="space-y-4">
      <div class="flex flex-col sm:flex-row gap-3">
        <input 
          type="email" 
          name="email" 
          placeholder="Enter your email address" 
          required
          class="input input-bordered flex-1 text-lg"
        />
        <button type="submit" class="btn btn-primary btn-lg px-8">
          Join the Movement
        </button>
      </div>
      <p class="text-sm text-base-content/60">
        Get updates on our nonprofit mission and early access to the platform
      </p>
    </form>
    """
  end

  defp social_proof(assigns) do
    ~H"""
    <div class="flex flex-wrap justify-center gap-8 text-base-content/60">
      <.proof_item icon="✅" text="100% Creator Earnings" />
      <.proof_item icon="🏛️" text="501c3 Nonprofit (applying)" />
      <.proof_item icon="🔓" text="Open Source" />
    </div>
    """
  end

  defp proof_item(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <span class="text-2xl"><%= @icon %></span>
      <span><%= @text %></span>
    </div>
    """
  end

  defp problem_section(assigns) do
    ~H"""
    <div class="py-20 bg-error/5">
      <div class="container mx-auto px-4">
        <div class="max-w-4xl mx-auto text-center">
          <h2 class="text-4xl md:text-5xl font-bold mb-8 text-error">
            The Problem with Traditional Platforms
          </h2>
          
          <div class="grid grid-cols-1 md:grid-cols-3 gap-8 mb-12">
            <.problem_card icon="💸" title="Massive Platform Fees" 
              description="Most platforms take 15-30% of creator earnings, leaving artists with scraps" />
            <.problem_card icon="🏢" title="Corporate Exploitation" 
              description="Billion-dollar companies profit from artists' work instead of supporting them" />
            <.problem_card icon="🚫" title="Limited Access" 
              description="Algorithms favor big brands, making it harder for independent creators to succeed" />
          </div>
          
          <div class="bg-error/10 rounded-xl p-8 border border-error/20">
            <h3 class="text-2xl font-bold mb-4 text-error">It's Time for a Better Way</h3>
            <p class="text-lg text-base-content/80">
              Shomp exists to break this cycle. We're building a marketplace where creators thrive, 
              communities connect, and every dollar goes further.
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp problem_card(assigns) do
    ~H"""
    <div class="bg-base-100 rounded-xl p-6 shadow-lg">
      <div class="text-4xl mb-4"><%= @icon %></div>
      <h3 class="text-xl font-bold mb-3"><%= @title %></h3>
      <p class="text-base-content/70"><%= @description %></p>
    </div>
    """
  end

  defp solution_section(assigns) do
    ~H"""
    <div class="py-20 bg-success/5">
      <div class="container mx-auto px-4">
        <div class="max-w-6xl mx-auto">
          <h2 class="text-4xl md:text-5xl font-bold text-center mb-16 text-success">
            The Shomp Solution
          </h2>
          
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center mb-16">
            <.solution_text />
            <.earnings_comparison />
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp solution_text(assigns) do
    ~H"""
    <div>
      <h3 class="text-3xl font-bold mb-6 text-success">Zero Platform Fees</h3>
      <p class="text-xl text-base-content/70 mb-6 leading-relaxed">
        Creators keep 100% of their earnings. The only fee is Stripe's standard payment processing (~2.9%), 
        which goes directly to payment security, not corporate profits.
      </p>
      <div class="space-y-4">
        <.benefit_item icon="✅" text="No monthly subscription fees" />
        <.benefit_item icon="✅" text="No percentage cuts on sales" />
        <.benefit_item icon="✅" text="No hidden charges or surprises" />
      </div>
    </div>
    """
  end

  defp benefit_item(assigns) do
    ~H"""
    <div class="flex items-center gap-3">
      <span class="text-2xl text-success"><%= @icon %></span>
      <span class="text-lg"><%= @text %></span>
    </div>
    """
  end

  defp earnings_comparison(assigns) do
    ~H"""
    <div class="bg-base-100 rounded-2xl p-8 shadow-xl">
      <div class="text-center">
        <div class="text-6xl mb-4">💰</div>
        <h4 class="text-2xl font-bold mb-4">Creator Earnings Comparison</h4>
        <div class="space-y-4">
          <div class="flex justify-between items-center p-3 bg-error/10 rounded-lg">
            <span>Traditional Platform (20% fee)</span>
            <span class="font-bold text-error">$80</span>
          </div>
          <div class="flex justify-between items-center p-3 bg-success/10 rounded-lg">
            <span>Shomp (0% fee)</span>
            <span class="font-bold text-success">$100</span>
          </div>
          <div class="text-sm text-base-content/60 mt-2">
            *Based on $100 sale, excluding payment processing fees
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp how_it_works_section(assigns) do
    ~H"""
    <div class="py-20 bg-base-100">
      <div class="container mx-auto px-4">
        <h2 class="text-4xl md:text-5xl font-bold text-center mb-16">How Shomp Works</h2>
        
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8 max-w-6xl mx-auto">
          <.step_card icon="��" title="1. Create" 
            description="Set up your store and list your digital or physical products" />
          <.step_card icon="🛒" title="2. Sell" 
            description="Customers discover and purchase your products through your store" />
          <.step_card icon="💳" title="3. Get Paid" 
            description="Receive 100% of your earnings directly to your bank account" />
          <.step_card icon="🚀" title="4. Grow" 
            description="Build your audience and expand your creative business" />
        </div>
      </div>
    </div>
    """
  end

  defp step_card(assigns) do
    ~H"""
    <div class="text-center">
      <div class="w-20 h-20 bg-primary/20 rounded-full flex items-center justify-center mx-auto mb-6">
        <span class="text-3xl"><%= @icon %></span>
      </div>
      <h3 class="text-xl font-bold mb-3"><%= @title %></h3>
      <p class="text-base-content/70"><%= @description %></p>
    </div>
    """
  end

  defp product_categories_section(assigns) do
    ~H"""
    <div class="py-20 bg-base-50">
      <div class="container mx-auto px-4">
        <h2 class="text-4xl md:text-5xl font-bold text-center mb-16">What You Can Sell on Shomp</h2>
        
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8 max-w-6xl mx-auto">
          <.category_card icon="💻" title="Digital Products" items={[
            "Digital art & illustrations",
            "Music & audio files", 
            "E-books & courses",
            "Software & templates",
            "Photography & graphics"
          ]} />
          <.category_card icon="📦" title="Physical Products" items={[
            "Art prints & paintings",
            "Handmade crafts",
            "Jewelry & accessories", 
            "Clothing & apparel",
            "Home decor items"
          ]} />
          <.category_card icon="🎯" title="Services" items={[
            "Custom commissions",
            "Design consultations",
            "Creative workshops",
            "Portfolio reviews",
            "Mentoring sessions"
          ]} />
        </div>
      </div>
    </div>
    """
  end

  defp category_card(assigns) do
    ~H"""
    <div class="bg-base-100 rounded-xl p-8 shadow-lg hover:shadow-xl transition-shadow">
      <div class="text-4xl mb-4"><%= @icon %></div>
      <h3 class="text-xl font-bold mb-3"><%= @title %></h3>
      <ul class="space-y-2 text-base-content/70">
        <%= for item <- @items do %>
          <li>• <%= item %></li>
        <% end %>
      </ul>
    </div>
    """
  end

  defp values_section(assigns) do
    ~H"""
    <div class="py-20 bg-primary text-primary-content">
      <div class="container mx-auto px-4">
        <h2 class="text-4xl md:text-5xl font-bold text-center mb-16">Our Values</h2>
        
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8 max-w-6xl mx-auto">
          <.value_card icon="🤝" title="Community First" 
            description="We believe art and creativity are community treasures that should be accessible to everyone" />
          <.value_card icon="🔓" title="Transparency" 
            description="Complete openness in our operations, development, and decision-making processes" />
          <.value_card icon="⚖️" title="Ethical Business" 
            description="Prioritizing what's best for creators over profit maximization" />
          <.value_card icon="🌟" title="Innovation" 
            description="Building cutting-edge tools that empower creators to succeed" />
          <.value_card icon="🌍" title="Accessibility" 
            description="Making selling art online accessible to creators of all backgrounds" />
          <.value_card icon="💪" title="Empowerment" 
            description="Giving creators the tools and platform they need to build sustainable businesses" />
        </div>
      </div>
    </div>
    """
  end

  defp value_card(assigns) do
    ~H"""
    <div class="text-center">
      <div class="w-16 h-16 bg-primary-content/20 rounded-full flex items-center justify-center mx-auto mb-4">
        <span class="text-2xl"><%= @icon %></span>
      </div>
      <h3 class="text-xl font-bold mb-3"><%= @title %></h3>
      <p class="opacity-90"><%= @description %></p>
    </div>
    """
  end

  defp technical_section(assigns) do
    ~H"""
    <div class="py-20 bg-base-100">
      <div class="container mx-auto px-4">
        <div class="max-w-4xl mx-auto text-center">
          <h2 class="text-4xl md:text-5xl font-bold mb-8">Built for Performance & Reliability</h2>
          <p class="text-xl text-base-content/70 mb-12">
            Shomp is built on modern, enterprise-grade technology that ensures your store is always available 
            and your customers have a seamless experience.
          </p>
          
          <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
            <.tech_card icon="⚡" title="Elixir/Phoenix" 
              description="Built on the same technology that powers WhatsApp and Discord" />
            <.tech_card icon="🔒" title="Enterprise Security" 
              description="Bank-level security with Stripe integration and GDPR compliance" />
            <.tech_card icon="🌐" title="Open Source" 
              description="Complete transparency and the ability to self-host if desired" />
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp tech_card(assigns) do
    ~H"""
    <div class="bg-base-200 rounded-xl p-6">
      <div class="text-3xl mb-4"><%= @icon %></div>
      <h3 class="text-lg font-bold mb-2"><%= @title %></h3>
      <p class="text-sm text-base-content/70"><%= @description %></p>
    </div>
    """
  end

  defp cta_section(assigns) do
    ~H"""
    <div class="py-20 bg-gradient-to-r from-primary to-secondary text-primary-content">
      <div class="container mx-auto px-4 text-center">
        <div class="max-w-3xl mx-auto">
          <h2 class="text-4xl md:text-5xl font-bold mb-6">Join the Creator Economy Revolution</h2>
          <p class="text-xl mb-8 opacity-90">
            Be part of a movement that puts creators first. Sign up to get early access to the platform 
            and help shape the future of ethical e-commerce.
          </p>
          
          <div class="max-w-md mx-auto mb-8">
            <%= if @subscribed do %>
              <.success_message />
            <% else %>
              <.signup_form />
            <% end %>
          </div>
          
          <div class="flex flex-wrap justify-center gap-6 text-sm opacity-80">
            <.audience_tag icon="🎨" text="For Digital Artists" />
            <.audience_tag icon="💻" text="For Software Developers" />
            <.audience_tag icon="📚" text="For Content Creators" />
            <.audience_tag icon="🎵" text="For Musicians" />
            <.audience_tag icon="🏪" text="For Small Business Owners" />
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp audience_tag(assigns) do
    ~H"""
    <span><%= @icon %> <%= @text %></span>
    """
  end

  defp faq_section(assigns) do
    ~H"""
    <div class="py-20 bg-base-50">
      <div class="container mx-auto px-4">
        <h2 class="text-4xl md:text-5xl font-bold text-center mb-16">Frequently Asked Questions</h2>
        
        <div class="max-w-4xl mx-auto space-y-6">
          <.faq_item question="How is Shomp different from other platforms?" 
            answer="Shomp is the only nonprofit e-commerce platform where creators keep 100% of their earnings. We're funded entirely by donations, not by taking a cut of creator sales." />
          <.faq_item question="When will the platform launch?" 
            answer="We're currently in development and will launch in phases. Sign up for our email list to get early access and development updates." />
          <.faq_item question="How do you sustain the platform without fees?" 
            answer="We're a 501c3 nonprofit sustained by community donations from people who believe in our mission. This allows us to focus purely on what's best for creators." />
          <.faq_item question="What types of products can I sell?" 
            answer="You can sell digital products (art, music, software, courses), physical products (prints, crafts, merchandise), and services (consultations, custom work, mentoring)." />
          <.faq_item question="Is Shomp really free to use?" 
            answer="Yes! There are no monthly fees, no listing fees, and no percentage cuts on sales. The only cost is Stripe's standard payment processing fee (~2.9%)." />
        </div>
      </div>
    </div>
    """
  end

  defp faq_item(assigns) do
    ~H"""
    <div class="bg-base-100 rounded-xl p-6 shadow-lg">
      <h3 class="text-xl font-bold mb-3"><%= @question %></h3>
      <p class="text-base-content/70"><%= @answer %></p>
    </div>
    """
  end

  defp final_cta_section(assigns) do
    ~H"""
    <div class="py-20 bg-base-100">
      <div class="container mx-auto px-4 text-center">
        <div class="max-w-2xl mx-auto">
          <h2 class="text-4xl md:text-5xl font-bold mb-6">Ready to Change the Game?</h2>
          <p class="text-xl text-base-content/70 mb-8">
            Join thousands of creators who are ready to take control of their earnings and build 
            sustainable creative businesses on their own terms.
          </p>
          
          <div class="flex flex-col sm:flex-row gap-4 justify-center">
            <%= if @subscribed do %>
              <.already_subscribed_message />
            <% else %>
              <.signup_form />
            <% end %>
          </div>
          
          <p class="text-sm text-base-content/60 mt-4">
            No spam, just updates on our mission to empower creators worldwide.
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp already_subscribed_message(assigns) do
    ~H"""
    <div class="bg-success/20 border border-success/30 rounded-lg p-6 text-center">
      <div class="text-4xl mb-3">🎉</div>
      <h3 class="text-xl font-bold text-success mb-2">You're Already Part of the Movement!</h3>
      <p class="text-success/80">
        Thank you for believing in our mission to empower creators worldwide.
      </p>
    </div>
    """
  end
end
