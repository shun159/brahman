defmodule Brahman.Metrics.Ewma do
  @moduledoc """
  ewma implements exponentially weighted moving averages.
  """

  # By default, we average over a one-minute period, which means the average
  # age of the metrics in the period is 30 seconds.
  @avg_metric_age 30.0

  # The formula for computing the decay factor from the average age comes
  # from "Production and Operations Analysis" by Steven Nahmias.
  @decay 2 / (@avg_metric_age + 1)

  # For best results, the moving average should not be initialized to the
  # samples it sees immediately. The book "Production and Operations
  # Analysis" by Steven Nahmias suggests initializing the moving average to
  # the mean of the first 10 samples. Until the VariableEwma has seen this
  # many samples, it is not "ready" to be queried for the value of the
  # moving average. This adds some memory cost.
  @warmup_samples 10

  defmodule Simple do
    @moduledoc """
    A SimpleEWMA represents the exponentially weighted moving average of a
    series of numbers. It WILL have different behavior than the VariableEWMA
    for multiple reasons. It has no warm-up period and it uses a constant
    decay.  These properties let it use less memory.  It will also behave
    differently when it's equal to zero, which is assumed to mean
    uninitialized, so if a value is likely to actually become zero over time,
    then any non-zero value will cause a sharp jump instead of a small change.
    However, note that this takes a long time, and the value may just
    decays to a stable value that's close to zero, but which won't be mistaken
    for uninitialized.
    """

    defstruct value: 0.0

    @typedoc """
    The current value of the average.
    """
    @type t :: %Simple{value: float()}
  end

  defmodule Variable do
    @moduledoc """
    VariableEWMA represents the exponentially weighted moving average of a series of
    numbers. Unlike SimpleEWMA, it supports a custom age, and thus uses more memory.
    """

    defstruct decay: 0.0, value: 0.0, count: 0

    @type t :: %Variable{
            # The multiplier factor by which the previous samples decay.
            decay: float(),
            # The current value of the average.
            value: float(),
            # The number of samples added to this instance.
            count: 0..255
          }
  end

  defmodule Peak do
    @moduledoc """
    Peak EWMA is designed to converge quickly when encountering
    slow endpoints. It is quick to react to latency spikes, recovering
    only cautiously. Peak EWMA takes history into account, so that
    slow behavior is penalized relative to the supplied decay time.
    """

    defstruct value: 0,
              stamp: :erlang.monotonic_time(:nano_seconds),
              penalty: 1.0e307,
              pending: 0,
              decay: 10.0e9

    @type t :: %Peak{
            # Current value of the exponentially weighted moving average.
            value: non_neg_integer(),
            # Used to measure the length of the exponential sliding window.
            stamp: integer(),
            # A large number for penalizing new backends, to ease up rates slowly.
            penalty: number(),
            # Number of in-flight measurements.
            pending: non_neg_integer(),
            # 10 seconds in nanoseconds
            decay: number()
          }
  end

  @doc """
  new/1 constructs a MovingAverage that computes an average with the
  desired characteristics in the moving window or exponential decay. If no
  age is given, it constructs a default exponentially weighted implementation
  that consumes minimal memory. The age is related to the decay factor alpha
  by the formula given for the DECAY constant. It signifies the average age
  of the samples as time goes to infinity.
  """
  @spec new(float() | integer() | :peak) :: Simple.t() | Variable.t() | Peak.t()
  def new(@avg_metric_age), do: %Simple{}

  def new(age) when is_integer(age) do
    age
    |> :erlang.float()
    |> new()
  end

  def new(age) when is_float(age), do: %Variable{decay: 2 / (age + 1)}

  def new(:peak), do: %Peak{}

  @doc """
  Add a value to the series and updates the moving average.
  """
  # this is a proxy for "uninitialized"
  @spec add(Simple.t() | Variable.t(), float() | integer()) :: Simple.t() | Variable.t()
  def add(%Simple{value: old_value} = ewma, new_value) when old_value == 0,
    do: %{ewma | value: new_value}

  def add(%Simple{} = ewma, value),
    do: %{ewma | value: value * @decay + ewma.value * (1 - @decay)}

  def add(%Variable{count: count} = ewma, value) when count < @warmup_samples,
    do: %{ewma | count: ewma.count + 1, value: ewma.value + value}

  def add(%Variable{count: @warmup_samples} = ewma, value) do
    value1 = ewma.value / :erlang.float(@warmup_samples)
    %{ewma | count: ewma.count + 1, value: value * ewma.decay + value1 * (1 - ewma.decay)}
  end

  def add(%Peak{value: cost, stamp: stamp, decay: decay}, value) do
    now = :erlang.monotonic_time(:nano_seconds)

    new_cost =
      now
      |> peak_ewma_weight(stamp, decay)
      |> peak_ewma_cost(cost, value)

    %Peak{stamp: now, value: new_cost}
  end

  def add(%Variable{} = ewma, value),
    do: %{ewma | value: value * ewma.decay + ewma.value * (1 - ewma.decay)}

  @doc """
  Value returns the current value of the moving average.
  """
  @spec value(Simple.t() | Variable.t() | Peak.t()) :: float()
  def value(%Simple{value: value}), do: value

  def value(%Variable{count: count}) when count < @warmup_samples, do: 0.0

  def value(%Variable{value: value}), do: value

  # If we don't have any latency history, we penalize the host on
  # the first probe. Otherwise, we factor in our current rate
  # assuming we were to schedule an additional request.
  def value(%Peak{value: cost, pending: pending} = ewma)
      when cost == 0 and pending != 0,
      do: ewma.penalty + ewma.pending

  def value(%Peak{value: cost} = ewma),
    do: cost * (ewma.pending + 1)

  @spec set(Simple.t() | Peak.t() | Variable.t(), float()) :: Simple.t() | Variable.t()
  def set(%Variable{count: count} = ewma0, value) do
    ewma1 = %{ewma0 | value: value}

    if count <= @warmup_samples,
      do: %{ewma1 | count: @warmup_samples + 1},
      else: ewma1
  end

  def set(ewma, value), do: %{ewma | value: value}

  # private functions

  defp peak_ewma_weight(now, stamp, decay) do
    now
    |> Kernel.-(stamp)
    |> Kernel.max(0)
    |> Kernel.-()
    |> Kernel./(decay)
    |> :math.exp()
  end

  @spec peak_ewma_cost(number(), float(), number()) :: float()
  defp peak_ewma_cost(_weight, cost, value) when value > cost,
    do: value

  defp peak_ewma_cost(weight, cost, value),
    do: cost * weight + value * (1.0 - weight)
end
