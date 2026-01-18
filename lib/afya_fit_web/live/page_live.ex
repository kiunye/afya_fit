defmodule AfyaFitWeb.PageLive do
  use AfyaFitWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} is_homepage={true}>
      <div class="relative min-h-screen overflow-hidden">
        <!-- Background & Atmosphere -->
        <div class="fixed inset-0 pointer-events-none">
          <!-- Animated Grid Pattern Overlay -->
          <div
            class="absolute inset-0 opacity-20"
            style="background-image: linear-gradient(rgba(255,255,255,0.1) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.1) 1px, transparent 1px); background-size: 50px 50px; mask-image: radial-gradient(ellipse 80% 50% at 50% 50%, black 40%, transparent 70%);"
          >
          </div>

          <!-- Floating Particles -->
          <div id="particles-container" class="absolute inset-0" phx-hook="Particles">
            <%= for i <- 0..19 do %>
              <div class="absolute w-1 h-1 bg-white rounded-full opacity-60 particle" data-index={i}>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Main Content -->
        <div class="relative z-10 container mx-auto px-4 sm:px-6 lg:px-8 pt-20 pb-32">
          <!-- Premium Badge -->
          <div class="flex justify-center mb-8 animate-fade-in">
            <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full border border-white/20 bg-white/5 backdrop-blur-sm">
              <div class="w-2 h-2 bg-red-500 rounded-full animate-pulse-dot"></div>
              <span class="text-sm font-medium text-gray-300">Now in Public Beta</span>
            </div>
          </div>

          <!-- Main Headline -->
          <div class="text-center mb-8 animate-fade-in-delay-1">
            <h1 class="text-6xl sm:text-7xl md:text-8xl lg:text-9xl font-extrabold mb-4 text-white">
              Transform Your
              <br />
              Fitness Business
            </h1>
          </div>

          <!-- Subheadline -->
          <div class="text-center mb-12 max-w-3xl mx-auto animate-fade-in-delay-2">
            <p class="text-xl sm:text-2xl text-gray-400 leading-relaxed">
              The all-in-one platform for <span class="text-white font-semibold">trainers</span> to manage clients,
              <span class="text-white font-semibold">workouts</span>,
              and <span class="text-white font-semibold">nutrition</span> with enterprise-grade reliability
            </p>
          </div>

          <!-- Stats Row -->
          <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-16 max-w-4xl mx-auto animate-fade-in-delay-3">
            <div class="text-center p-6 rounded-2xl bg-white/5 backdrop-blur-sm border border-white/10 hover:border-white/20 transition-all duration-300 hover:scale-105">
              <div class="text-3xl font-bold mb-2 text-white">
                99.9%
              </div>
              <div class="text-gray-400 text-sm">Uptime</div>
            </div>
            <div class="text-center p-6 rounded-2xl bg-white/5 backdrop-blur-sm border border-white/10 hover:border-white/20 transition-all duration-300 hover:scale-105">
              <div class="text-3xl font-bold mb-2 text-white">
                &lt;2s
              </div>
              <div class="text-gray-400 text-sm">Deploy Time</div>
            </div>
            <div class="text-center p-6 rounded-2xl bg-white/5 backdrop-blur-sm border border-white/10 hover:border-white/20 transition-all duration-300 hover:scale-105">
              <div class="text-3xl font-bold mb-2 text-white">
                $0
              </div>
              <div class="text-gray-400 text-sm">Setup Cost</div>
            </div>
          </div>

          <!-- CTA Buttons -->
          <div class="flex flex-col sm:flex-row items-center justify-center gap-4 mb-16 animate-fade-in-delay-4">
            <a
              href={~p"/users/register"}
              class="group relative h-14 px-8 rounded-full bg-[#cc0000] text-white font-semibold text-lg flex items-center gap-2 shadow-[0_0_30px_rgba(204,0,0,0.5)] hover:shadow-[0_0_40px_rgba(204,0,0,0.7)] transition-all duration-300 hover:scale-105 hover:bg-[#b80f0a]"
            >
              <span>Get Started Free</span>
              <.icon name="hero-arrow-right" class="w-5 h-5 group-hover:translate-x-1 transition-transform" />
            </a>
            <a
              href={~p"/users/log_in"}
              class="group h-14 px-8 rounded-full border-2 border-white/20 bg-white/5 backdrop-blur-sm text-white font-semibold text-lg flex items-center gap-2 hover:border-white/40 hover:bg-white/10 transition-all duration-300"
            >
              <span>Sign In</span>
              <.icon name="hero-arrow-right-on-rectangle" class="w-5 h-5 group-hover:translate-x-1 transition-transform" />
            </a>
          </div>

          <!-- Dashboard Preview -->
          <div class="max-w-6xl mx-auto animate-fade-in-delay-5">
            <div
              class="relative h-[500px] rounded-2xl overflow-hidden border-2 border-white/20"
              style="box-shadow: 0 0 40px rgba(0, 0, 0, 0.5);"
            >
              <!-- Border Layer -->
              <div class="absolute inset-[2px] rounded-2xl bg-slate-950"></div>

              <!-- Animated Grid Overlay Inside -->
              <div
                class="absolute inset-0 opacity-10"
                style="background-image: linear-gradient(rgba(255,255,255,0.1) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.1) 1px, transparent 1px); background-size: 20px 20px;"
              >
              </div>

              <!-- Shimmer Animation -->
              <div class="absolute inset-0 shimmer-overlay"></div>

              <!-- Mock Dashboard Content -->
              <div class="relative z-10 h-full flex flex-col">
                <!-- Browser Chrome -->
                <div class="flex items-center gap-2 p-4 bg-slate-900/50 border-b border-white/10">
                  <div class="flex gap-2">
                    <div class="w-3 h-3 rounded-full bg-red-500"></div>
                    <div class="w-3 h-3 rounded-full bg-yellow-500"></div>
                    <div class="w-3 h-3 rounded-full bg-green-500"></div>
                  </div>
                  <div class="flex-1 mx-4 h-8 bg-slate-800/50 rounded-lg border border-white/10"></div>
                </div>

                <!-- Content Area -->
                <div class="flex-1 p-6">
                  <div class="grid grid-cols-1 md:grid-cols-3 gap-4 h-full">
                    <!-- Card 1 -->
                    <div class="rounded-xl bg-slate-900/50 border border-white/10 p-6 backdrop-blur-sm">
                      <div class="h-4 w-24 bg-white/20 rounded mb-3"></div>
                      <div class="h-8 w-32 bg-white/30 rounded mb-2"></div>
                      <div class="h-3 w-40 bg-white/10 rounded"></div>
                    </div>
                    <!-- Card 2 -->
                    <div class="rounded-xl bg-slate-900/50 border border-white/10 p-6 backdrop-blur-sm">
                      <div class="h-4 w-24 bg-white/20 rounded mb-3"></div>
                      <div class="h-8 w-32 bg-white/30 rounded mb-2"></div>
                      <div class="h-3 w-40 bg-white/10 rounded"></div>
                    </div>
                    <!-- Card 3 -->
                    <div class="rounded-xl bg-slate-900/50 border border-white/10 p-6 backdrop-blur-sm">
                      <div class="h-4 w-24 bg-white/20 rounded mb-3"></div>
                      <div class="h-8 w-32 bg-white/30 rounded mb-2"></div>
                      <div class="h-3 w-40 bg-white/10 rounded"></div>
                    </div>
                  </div>
                </div>

                <!-- Bottom Stats Bar -->
                <div class="p-4 bg-slate-900/50 border-t border-white/10">
                  <div class="flex items-center justify-between">
                    <div class="flex gap-6">
                      <div class="h-3 w-20 bg-white/20 rounded"></div>
                      <div class="h-3 w-20 bg-white/20 rounded"></div>
                      <div class="h-3 w-20 bg-white/20 rounded"></div>
                    </div>
                    <div class="h-3 w-16 bg-white/20 rounded"></div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    if user && user.role == "trainer" do
      {:ok, push_navigate(socket, to: ~p"/trainer/dashboard")}
    else
      {:ok, socket}
    end
  end
end
