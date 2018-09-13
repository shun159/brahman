defmodule EwmaTest do
  use ExUnit.Case
  doctest Brahman

  @samples_int_list [
    4599,
    5711,
    4746,
    4621,
    5037,
    4218,
    4925,
    4281,
    5207,
    5203,
    5594,
    5149,
    4948,
    4994,
    6056,
    4417,
    4973,
    4714,
    4964,
    5280,
    5074,
    4913,
    4119,
    4522,
    4631,
    4341,
    4909,
    4750,
    4663,
    5167,
    3683,
    4964,
    5151,
    4892,
    4171,
    5097,
    3546,
    4144,
    4551,
    6557,
    4234,
    5026,
    5220,
    4144,
    5547,
    4747,
    4732,
    5327,
    5442,
    4176,
    4907,
    3570,
    4684,
    4161,
    5206,
    4952,
    4317,
    4819,
    4668,
    4603,
    4885,
    4645,
    4401,
    4362,
    5035,
    3954,
    4738,
    4545,
    5433,
    6326,
    5927,
    4983,
    5364,
    4598,
    5071,
    5231,
    5250,
    4621,
    4269,
    3953,
    3308,
    3623,
    5264,
    5322,
    5395,
    4753,
    4936,
    5315,
    5243,
    5060,
    4989,
    4921,
    4480,
    3426,
    3687,
    4220,
    3197,
    5139,
    6101,
    5279
  ]

  @samples Enum.map(@samples_int_list, &:erlang.float/1)

  @mergin 0.00000001

  test "with Simple EWMA" do
    ewma0 = %Brahman.Ewma.Simple{}
    ewma1 = Enum.reduce(@samples, ewma0, &Brahman.Ewma.add(&2, &1))
    assert within_mergin?(ewma1.value, 4734.500946466118)
    assert Brahman.Ewma.set(ewma1, 1.0).value == 1.0
  end

  test "with Simple EWMA and age = 30" do
    ewma0 = Brahman.Ewma.new(30)
    ewma1 = Enum.reduce(@samples, ewma0, &Brahman.Ewma.add(&2, &1))
    assert within_mergin?(ewma1.value, 4734.500946466118)
    assert Brahman.Ewma.set(ewma1, 1.0).value == 1.0
  end

  test "with Variable EWMA with age = 5" do
    ewma0 = Brahman.Ewma.new(5)
    ewma1 = Enum.reduce(@samples, ewma0, &Brahman.Ewma.add(&2, &1))
    assert within_mergin?(ewma1.value, 5015.397367486725)
  end

  test "with Variable EWMA with warmup 1" do
    _ = Enum.reduce(@samples, {Brahman.Ewma.new(5), 1}, &check_warmup/2)
    ewma0 = Brahman.Ewma.new(5)
    ewma1 = Brahman.Ewma.set(ewma0, 5)
    ewma2 = Brahman.Ewma.add(ewma1, 1)
    refute Brahman.Ewma.value(ewma2) >= 5
  end

  test "with Variable EWMA with " do
    samples = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 10_000, 1] |> Enum.map(&:erlang.float/1)
    {ewma, _count} = Enum.reduce(@samples, {Brahman.Ewma.new(5), 1}, &check_warmup/2)
    refute Brahman.Ewma.value(ewma) == 1.0
  end

  # helper

  defp within_mergin?(a, expect), do: abs(a - expect) <= @mergin

  defp check_warmup(value, {tmp_ewma, count}) do
    ewma = Brahman.Ewma.add(tmp_ewma, value)
    if count < 10, do: assert(Brahman.Ewma.value(ewma) == 0.0)
    {ewma, count + 1}
  end
end
