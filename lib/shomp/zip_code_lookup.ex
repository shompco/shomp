defmodule Shomp.ZipCodeLookup do
  @moduledoc """
  Utility module for looking up US states from ZIP codes.
  Uses ZIP code ranges to determine the state.
  """

  @zip_ranges %{
    # Alabama
    "AL" => [35000..36999],

    # Alaska
    "AK" => [99500..99999],

    # Arizona
    "AZ" => [85000..86999],

    # Arkansas
    "AR" => [71600..72999, 75500..75599],

    # California
    "CA" => [90000..96699],

    # Colorado
    "CO" => [80000..81999],

    # Connecticut
    "CT" => [6000..6999],

    # Delaware
    "DE" => [19700..19999],

    # District of Columbia
    "DC" => [20000..20599],

    # Florida
    "FL" => [32000..34999],

    # Georgia
    "GA" => [30000..31999, 39800..39999],

    # Hawaii
    "HI" => [96700..96999],

    # Idaho
    "ID" => [83200..83999],

    # Illinois
    "IL" => [60000..62999],

    # Indiana
    "IN" => [46000..47999],

    # Iowa
    "IA" => [50000..52999],

    # Kansas
    "KS" => [66000..67999],

    # Kentucky
    "KY" => [40000..42999],

    # Louisiana
    "LA" => [70000..71499],

    # Maine
    "ME" => [3900..4999],

    # Maryland
    "MD" => [20600..21999],

    # Massachusetts
    "MA" => [1000..2799, 5500..5999],

    # Michigan
    "MI" => [48000..49999],

    # Minnesota
    "MN" => [55000..56999],

    # Mississippi
    "MS" => [38600..39799],

    # Missouri
    "MO" => [63000..65999],

    # Montana
    "MT" => [59000..59999],

    # Nebraska
    "NE" => [68000..69999],

    # Nevada
    "NV" => [89000..89999],

    # New Hampshire
    "NH" => [3000..3899],

    # New Jersey
    "NJ" => [7000..8999],

    # New Mexico
    "NM" => [87000..88999],

    # New York
    "NY" => [10000..14999],

    # North Carolina
    "NC" => [27000..28999],

    # North Dakota
    "ND" => [58000..58999],

    # Ohio
    "OH" => [43000..45999],

    # Oklahoma
    "OK" => [73000..74999],

    # Oregon
    "OR" => [97000..97999],

    # Pennsylvania
    "PA" => [15000..19999],

    # Rhode Island
    "RI" => [2800..2999],

    # South Carolina
    "SC" => [29000..29999],

    # South Dakota
    "SD" => [57000..57999],

    # Tennessee
    "TN" => [37000..38599],

    # Texas
    "TX" => [75000..79999, 88500..88599],

    # Utah
    "UT" => [84000..84999],

    # Vermont
    "VT" => [5000..5999],

    # Virginia
    "VA" => [22000..24699],

    # Washington
    "WA" => [98000..99499],

    # West Virginia
    "WV" => [24700..26999],

    # Wisconsin
    "WI" => [53000..54999],

    # Wyoming
    "WY" => [82000..83999]
  }

  @doc """
  Looks up the state abbreviation for a given ZIP code.

  ## Examples

      iex> Shomp.ZipCodeLookup.state_from_zip("10001")
      "NY"

      iex> Shomp.ZipCodeLookup.state_from_zip("90210")
      "CA"

      iex> Shomp.ZipCodeLookup.state_from_zip("12345")
      nil
  """
  def state_from_zip(zip_code) when is_binary(zip_code) do
    case Integer.parse(zip_code) do
      {zip_int, ""} -> state_from_zip(zip_int)
      _ -> nil
    end
  end

  def state_from_zip(zip_code) when is_integer(zip_code) do
    Enum.find_value(@zip_ranges, fn {state, ranges} ->
      if Enum.any?(ranges, fn range -> zip_code in range end) do
        state
      end
    end)
  end

  def state_from_zip(_), do: nil

  @doc """
  Creates a complete address map with state determined from ZIP code.

  ## Examples

      iex> Shomp.ZipCodeLookup.create_address_from_zip("10001")
      %{city: "Store", state: "NY", zip: "10001", country: "US"}

      iex> Shomp.ZipCodeLookup.create_address_from_zip("90210")
      %{city: "Store", state: "CA", zip: "90210", country: "US"}
  """
  def create_address_from_zip(zip_code) do
    case state_from_zip(zip_code) do
      nil ->
        # Fallback to NY if ZIP not found
        %{
          city: "Store",
          state: "NY",
          zip: zip_code,
          country: "US"
        }
      state ->
        %{
          city: "Store",
          state: state,
          zip: zip_code,
          country: "US"
        }
    end
  end
end
