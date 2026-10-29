defmodule AfyaFitWeb.SignComponents do
  @moduledoc """
  The venue-signage building blocks described in `docs/design/DIRECTION.md`:
  pictograms, signs (rows), grouped lists, closed signs for features the plan
  does not include, the limit dialog and the account banner.

  Everything is Tailwind v4 utilities over the tokens in `assets/css/app.css`.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  # Pictograms: 48px grid, 3px stroke, round caps. One hand for the whole set.
  @pictograms %{
    today:
      ~s(<rect pathLength="1" x="7" y="10" width="34" height="30" rx="3"/><path pathLength="1" d="M7 19h34M15 5v9M33 5v9"/>),
    home: ~s(<path pathLength="1" d="M6 22L24 7l18 15M12 20v20h24V20M20 40V28h8v12"/>),
    clients:
      ~s(<circle pathLength="1" cx="18" cy="16" r="6"/><path pathLength="1" d="M6 40c1-9 6-13 12-13s11 4 12 13M32 12a6 6 0 010 11M36 28c4 2 6 6 6 12"/>),
    add_client:
      ~s(<circle pathLength="1" cx="18" cy="16" r="6"/><path pathLength="1" d="M6 40c1-9 6-13 12-13s11 4 12 13M36 14v14M29 21h14"/>),
    workouts: ~s(<path pathLength="1" d="M5 18v12M11 12v24M37 12v24M43 18v12M11 24h26"/>),
    nutrition: ~s(<path pathLength="1" d="M8 22h32l-3 18H11zM15 22a9 9 0 0118 0M24 8v5"/>),
    progress: ~s(<path pathLength="1" d="M8 40V24M20 40V8M32 40V28M44 40H4"/>),
    team:
      ~s(<circle pathLength="1" cx="24" cy="14" r="7"/><path pathLength="1" d="M10 42c1-10 7-15 14-15s13 5 14 15M34 6l6 4"/>),
    billing:
      ~s(<rect pathLength="1" x="5" y="11" width="38" height="26" rx="3"/><path pathLength="1" d="M5 19h38M11 30h10"/>),
    platform:
      ~s(<rect pathLength="1" x="6" y="8" width="36" height="12" rx="2"/><rect pathLength="1" x="6" y="28" width="36" height="12" rx="2"/><path pathLength="1" d="M12 14h4M12 34h4"/>),
    runner:
      ~s(<circle pathLength="1" cx="26" cy="9" r="4"/><path pathLength="1" d="M14 22l8-5 8 6 7 2M22 17l-4 12 9 4-3 11M18 29l-8 8"/>),
    camera:
      ~s(<rect pathLength="1" x="5" y="14" width="38" height="26" rx="3"/><circle pathLength="1" cx="24" cy="27" r="7"/><path pathLength="1" d="M17 14l3-6h8l3 6"/>),
    repeat:
      ~s(<path pathLength="1" d="M8 20v-4a6 6 0 016-6h22M36 10l-5-5M36 10l-5 5M40 28v4a6 6 0 01-6 6H12M12 38l5 5M12 38l5-5"/>),
    lock:
      ~s(<rect pathLength="1" x="10" y="22" width="28" height="20" rx="3"/><path pathLength="1" d="M16 22v-6a8 8 0 0116 0v6M24 30v5"/>),
    alert: ~s(<path pathLength="1" d="M24 8v22M24 38v2"/>),
    settings:
      ~s(<circle pathLength="1" cx="24" cy="24" r="6"/><path pathLength="1" d="M24 6v6M24 36v6M6 24h6M36 24h6M11 11l4 4M33 33l4 4M37 11l-4 4M15 33l-4 4"/>),
    more:
      ~s(<circle pathLength="1" cx="10" cy="24" r="2.5"/><circle pathLength="1" cx="24" cy="24" r="2.5"/><circle pathLength="1" cx="38" cy="24" r="2.5"/>)
  }

  @doc "The pictogram names, for tests and previews."
  def pictogram_names, do: Map.keys(@pictograms)

  @doc """
  Renders a pictogram. With `draw`, the strokes draw themselves on insertion
  (see `.pictogram-draw` in `app.css`; reduced motion shows them drawn).
  """
  attr :name, :atom, required: true
  attr :class, :any, default: "size-9"
  attr :draw, :boolean, default: false

  def pictogram(assigns) do
    assigns = assign(assigns, :paths, Phoenix.HTML.raw(Map.fetch!(@pictograms, assigns.name)))

    ~H"""
    <svg
      viewBox="0 0 48 48"
      fill="none"
      stroke="currentColor"
      stroke-width="3"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
      class={[@class, @draw && "pictogram-draw"]}
    >
      {@paths}
    </svg>
    """
  end

  @doc """
  A square tile holding a pictogram. State is shown by fill and outline, never
  by extra hues: `:done` is white, `:next` is the orange signal, `:later` is an
  outline, `:closed` is dashed.
  """
  attr :icon, :atom, required: true
  attr :state, :atom, values: [:done, :next, :later, :closed], default: :later
  attr :draw, :boolean, default: true

  def tile(assigns) do
    ~H"""
    <div class={[
      "grid size-[60px] shrink-0 place-items-center rounded-tile border-[3px] sm:size-[68px]",
      @state == :later && "border-line text-ink",
      @state == :closed && "border-dashed border-line text-ink",
      @state == :done && "border-white bg-white text-field-0",
      @state == :next && "border-signal bg-signal text-signal-ink"
    ]}>
      <.pictogram name={@icon} draw={@draw} class="size-9 sm:size-10" />
    </div>
    """
  end

  @doc """
  A sign: tile, time or number, name and detail, one action. The workhorse row.

      <.sign icon={:workouts} state={:done} time="07:00" time_label="Done">
        <:title>Otieno Odhiambo</:title>
        Lower body B · week 6 of 12
        <:actions><.sign_action navigate={~p"/trainer/clients/1"}>Open</.sign_action></:actions>
      </.sign>
  """
  attr :icon, :atom, required: true
  attr :state, :atom, values: [:done, :next, :later, :closed], default: :later
  attr :time, :string, default: nil
  attr :time_label, :string, default: nil
  attr :overdue, :boolean, default: false
  attr :draw, :boolean, default: true
  attr :rest, :global

  slot :title, required: true
  slot :inner_block
  slot :actions

  def sign(assigns) do
    ~H"""
    <div
      class="grid grid-cols-[60px_1fr] items-center gap-x-4 gap-y-2 border-b border-line/40 px-4 py-3.5 hover:bg-field-2 sm:grid-cols-[68px_150px_minmax(0,1fr)_auto] sm:gap-x-[18px] sm:px-[26px]"
      {@rest}
    >
      <.tile icon={@icon} state={@state} draw={@draw} />
      <div class="min-w-0">
        <div :if={@time} class="text-2xl font-extrabold leading-none tabular-nums">{@time}</div>
        
        <div :if={@time_label} class="mt-1 text-xs font-bold uppercase tracking-[.06em] text-ink-2">
          {@time_label}
        </div>
      </div>
      
      <div class="col-span-2 min-w-0 sm:col-span-1">
        <div class="text-xl font-bold leading-tight">
          {render_slot(@title)} <span :if={@state == :closed} class={tag_class()}>Pro</span>
        </div>
        
        <div :if={@inner_block != [] || @overdue} class="text-sm text-ink-2">
          <span
            :if={@overdue}
            class="mr-1.5 inline-block size-2.5 rounded-full bg-signal align-middle"
          >
          </span> <span :if={@overdue} class="font-bold text-ink">Overdue</span>
          <span :if={@overdue && @inner_block != []}> · </span> {render_slot(@inner_block)}
        </div>
      </div>
      
      <div
        :if={@actions != []}
        class="col-span-2 flex flex-wrap gap-2 sm:col-span-1 sm:justify-end"
      >
        {render_slot(@actions)}
      </div>
    </div>
    """
  end

  defp tag_class,
    do:
      "ml-2 rounded-[3px] border-2 border-line px-1.5 align-[2px] text-xs font-bold uppercase tracking-[.06em]"

  @doc "The action on a sign. `primary` is the one orange action; at most one per screen area."
  attr :primary, :boolean, default: false

  attr :rest, :global,
    include: ~w(href navigate patch method phx-click phx-value-id type disabled aria-disabled)

  slot :inner_block, required: true

  def sign_action(assigns) do
    ~H"""
    <AfyaFitWeb.CoreComponents.button variant={if @primary, do: "primary", else: "default"} {@rest}>
      {render_slot(@inner_block)}
    </AfyaFitWeb.CoreComponents.button>
    """
  end

  @doc "A labelled group of signs, with an optional action on the right of the label."
  attr :label, :string, required: true
  slot :actions
  slot :inner_block, required: true

  def sign_group(assigns) do
    ~H"""
    <section aria-label={@label}>
      <div class="flex items-center gap-3 px-4 pb-2 pt-5 sm:px-[26px]">
        <h2 class="text-xs font-bold uppercase tracking-[.08em] text-ink-2">{@label}</h2>
        
        <div :if={@actions != []} class="ml-auto">{render_slot(@actions)}</div>
      </div>
      
      <div class="border-t border-line/40">{render_slot(@inner_block)}</div>
    </section>
    """
  end

  @doc """
  The page header: one big title, one sentence of state, actions on the right.
  A 3px rule closes it.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def page_header(assigns) do
    ~H"""
    <header class="flex flex-wrap items-end gap-x-6 gap-y-2 border-b-[3px] border-line px-4 pb-4 pt-5 sm:px-[26px]">
      <h1 class="text-[32px] font-black uppercase leading-[.95] tracking-[-.01em] sm:text-5xl">
        {render_slot(@inner_block)}
      </h1>
      
      <p :if={@subtitle != []} class="max-w-[44ch] text-ink-2 sm:ml-auto sm:text-right">
        {render_slot(@subtitle)}
      </p>
      
      <div :if={@actions != []} class="flex gap-2">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  A feature the plan does not include, shown in place of the feature. Org
  admins get an upgrade action; everyone else is told who to ask.
  """
  attr :icon, :atom, required: true
  attr :title, :string, required: true
  attr :can_upgrade, :boolean, default: false
  attr :owner_name, :string, default: nil
  attr :upgrade_path, :string, default: "/billing"
  attr :rest, :global

  slot :inner_block, required: true

  def closed_sign(assigns) do
    ~H"""
    <.sign icon={@icon} state={:closed} draw={false} {@rest}>
      <:title>{@title}</:title>
       {render_slot(@inner_block)}
      <span :if={!@can_upgrade && @owner_name} class="block">
        Ask {@owner_name} (owner) to upgrade.
      </span>
      <:actions :if={@can_upgrade}>
        <.sign_action primary navigate={@upgrade_path}>Upgrade to Pro</.sign_action>
      </:actions>
    </.sign>
    """
  end

  @doc """
  The dialog shown when an action is blocked by the plan. Focus stays inside it
  and Escape or "Not now" closes it by pushing `on_cancel`.
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :icon, :atom, default: :add_client
  attr :current_label, :string, required: true
  attr :current_value, :string, required: true
  attr :upgraded_label, :string, default: "Pro"
  attr :upgraded_value, :string, required: true
  attr :can_upgrade, :boolean, default: false
  attr :owner_name, :string, default: nil
  attr :upgrade_path, :string, default: "/billing"
  attr :on_cancel, JS, default: %JS{}

  slot :inner_block, required: true

  def limit_dialog(assigns) do
    ~H"""
    <div
      id={@id}
      class="fixed inset-0 z-40 grid place-items-center bg-[rgb(3_30_22/0.72)] p-4"
      phx-window-keydown={@on_cancel}
      phx-key="escape"
    >
      <.focus_wrap
        id={"#{@id}-wrap"}
        role="dialog"
        aria-modal="true"
        aria-labelledby={"#{@id}-title"}
        class="w-full max-w-[520px] rounded-tile border-[3px] border-field-0 bg-paper p-6 text-field-0 shadow-[6px_6px_0_var(--color-field-0)]"
      >
        <div class="mb-3.5 grid size-[60px] place-items-center rounded-tile border-[3px] border-field-0">
          <.pictogram name={@icon} class="size-9" />
        </div>
        
        <h2 id={"#{@id}-title"} class="mb-2 text-[26px] font-black uppercase leading-[1.05]">
          {@title}
        </h2>
        
        <p class="mb-3.5 text-[#274c40]">{render_slot(@inner_block)}</p>
        
        <div class="mb-4 grid grid-cols-2 rounded-control border-[3px] border-field-0">
          <div class="p-3">
            <small class="mb-1 block text-xs font-bold uppercase tracking-[.08em]">
              {@current_label}
            </small> <b class="text-[28px] font-black leading-none">{@current_value}</b>
          </div>
          
          <div class="border-l-[3px] border-field-0 bg-field-0 p-3 text-white">
            <small class="mb-1 block text-xs font-bold uppercase tracking-[.08em]">
              {@upgraded_label}
            </small> <b class="text-[28px] font-black leading-none">{@upgraded_value}</b>
          </div>
        </div>
        
        <p :if={!@can_upgrade && @owner_name} class="mb-4 text-sm font-bold">
          Ask {@owner_name} (owner) to upgrade.
        </p>
        
        <div class="flex flex-wrap gap-2.5">
          <.dialog_button :if={@can_upgrade} primary navigate={@upgrade_path}>
            Upgrade to Pro
          </.dialog_button> <.dialog_button phx-click={@on_cancel}>Not now</.dialog_button>
        </div>
      </.focus_wrap>
    </div>
    """
  end

  attr :primary, :boolean, default: false
  attr :rest, :global, include: ~w(href navigate patch phx-click)
  slot :inner_block, required: true

  defp dialog_button(assigns) do
    ~H"""
    <AfyaFitWeb.CoreComponents.button
      class={[
        "border-field-0! text-field-0! hover:bg-field-0! hover:text-white! focus-visible:outline-field-0!",
        @primary && "bg-signal! text-signal-ink!"
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </AfyaFitWeb.CoreComponents.button>
    """
  end

  @doc """
  The account banner. `:grace` is an outlined bar (full access, payment needs
  attention); `:read_only` is the solid orange bar (writes are paused).
  """
  attr :state, :atom, values: [:grace, :read_only], required: true
  slot :inner_block, required: true
  slot :action

  def account_banner(assigns) do
    ~H"""
    <div
      role="status"
      class={[
        "flex flex-wrap items-center gap-x-4 gap-y-2 px-4 py-2.5 text-sm font-bold sm:px-[26px]",
        @state == :read_only && "bg-signal text-signal-ink",
        @state == :grace && "border-t-[3px] border-t-signal bg-field-0 text-ink"
      ]}
    >
      <span>{render_slot(@inner_block)}</span>
      <div :if={@action != []} class="sm:ml-auto">
        <span class={[
          "inline-block rounded-control px-3.5 py-1.5 text-[13px] font-extrabold uppercase tracking-[.03em]",
          @state == :read_only && "bg-signal-ink text-white",
          @state == :grace && "bg-signal text-signal-ink"
        ]}>
          {render_slot(@action)}
        </span>
      </div>
    </div>
    """
  end

  @doc """
  The full-page sign for a page the user may not open, or that is not there.
  Names who can help and links back to a page that works.
  """
  attr :kind, :atom, values: [:forbidden, :not_found], default: :forbidden
  attr :message, :string, required: true
  attr :back_path, :string, default: "/"

  def denied_sign(assigns) do
    ~H"""
    <div id="denied" class="px-4 py-10 sm:px-[26px]">
      <div class="flex max-w-xl flex-col gap-5">
        <div class="grid size-[68px] place-items-center rounded-tile border-[3px] border-dashed border-line">
          <.pictogram name={:lock} class="size-10" />
        </div>
        
        <h1 class="text-3xl font-black uppercase leading-none sm:text-4xl">
          {if @kind == :forbidden, do: "Not for your role", else: "Not found"}
        </h1>
        
        <p class="text-lg text-ink-2">{@message}</p>
        
        <div>
          <AfyaFitWeb.CoreComponents.button navigate={@back_path}>
            Back to home
          </AfyaFitWeb.CoreComponents.button>
        </div>
      </div>
    </div>
    """
  end

  @doc "A status dot for overdue and needs-attention states. Always pair it with a word."
  def attention_dot(assigns) do
    ~H"""
    <span class="inline-block size-2.5 rounded-full bg-signal align-middle"></span>
    """
  end
end
