defmodule Gaoxy.Proxy.UpstreamTransports.Options do
  @moduledoc """
  Pure preparation of immutable H1 resources and their finite owner limits.

  Limits have no defaults. At most 64 resources, 4096 metadata pins, 2048
  request tokens and 64 MiB of owned serialized payload may be admitted by an
  owner. The token ceiling matches 64 resources at the fixed R32 profile.

  `owned_serialized_payload_bytes` counts the external-term representation of
  the compact prepared value. It is not a VM, socket or native memory bound.
  The preparation manifest separately records constructor and binary backing
  facts. Neither operation creates a process or opens a managed scope.
  """

  alias Gaoxy.Proxy.ManagedH1Preparation

  def normalize_limits(
        %{
          max_resources: resources,
          max_pins: pins,
          max_request_tokens: tokens,
          max_owned_payload_bytes: payload
        } = limits
      )
      when map_size(limits) == 4 and is_integer(resources) and resources in 1..64 and
             is_integer(pins) and pins in 1..4096 and is_integer(tokens) and tokens in 1..2048 and
             is_integer(payload) and payload in 1..67_108_864,
      do: {:ok, limits}

  def normalize_limits(_), do: {:error, :invalid_limits}

  def prepare_policy(source) do
    with {:ok, policy, manifest} <- ManagedH1Preparation.prepare_policy(source) do
      {:ok, policy, accounting(policy, manifest)}
    end
  end

  def prepare_request(policy, source) do
    with {:ok, request, manifest} <- ManagedH1Preparation.prepare_request(policy, source) do
      {:ok, request, accounting(request, manifest)}
    end
  end

  # Only bounded, validated and compact values reach serialization accounting.
  defp accounting(prepared, manifest) do
    %{
      owned_serialized_payload_bytes: :erlang.external_size(prepared),
      preparation: manifest
    }
  end
end
