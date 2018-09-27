[]# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :brahman,
  forward_zones: %{
    "captive.cap" => [{{127, 0, 0, 1}, 18053}]
  }

config :erldns,
  servers: [
    [
      name: :inet_localhost_1,
      address: '127.0.0.1',
      port: 18053,
      family: :inet,
      processes: 2
    ],
    [
      name: :inet_localhost_2,
      address: '127.0.0.1',
      port: 18054,
      family: :inet,
      processes: 2
    ],
    [
      name: :inet_localhost_3,
      address: '127.0.0.1',
      port: 18055,
      family: :inet,
      processes: 2
    ]
  ],
  dnssec: [enabled: false],
  use_root_hints: false,
  zones: 'priv/zones.json',
  pools: []

config :exometer_core,
  report: [reporters: []]

config :elixometer,
  reporter: :exometer_report_tty,
  metric_prefix: "brahman"

config :sasl,
  sasl_error_logger: :tty,
  errlog_type: :error,
  # Log directory
  error_logger_mf_dir: 'log/sasl',
  # 10 MB max file size
  error_logger_mf_maxbytes: 10_485_760,
  # 5 files max
  error_logger_mf_maxfiles: 5

config :logger,
  level: :error,
  format: "$date $time [$level] $metadata$message",
  metadata: [:application],
  handle_otp_reports: true
