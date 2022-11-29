defmodule SpawnOperator.K8s.Deployment do
  @moduledoc false

  @behaviour SpawnOperator.K8s.Manifest

  @default_actor_host_function_env [
    %{
      "name" => "NAMESPACE",
      "valueFrom" => %{"fieldRef" => %{"fieldPath" => "metadata.namespace"}}
    },
    %{
      "name" => "POD_IP",
      "valueFrom" => %{"fieldRef" => %{"fieldPath" => "status.podIP"}}
    },
    %{
      "name" => "NODE_IP",
      "valueFrom" => %{"fieldRef" => %{"fieldPath" => "status.hostIP"}}
    },
    %{
      "name" => "SPAWN_PROXY_PORT",
      "value" => "9001"
    },
    %{
      "name" => "SPAWN_PROXY_INTERFACE",
      "value" => "0.0.0.0"
    }
  ]

  @default_actor_host_function_ports [
    %{"containerPort" => 4369, "name" => "epmd"},
    %{"containerPort" => 9000, "name" => "proxy-http"},
    %{"containerPort" => 9001, "name" => "proxy-https"}
  ]

  @default_actor_host_function_replicas 1

  @default_actor_host_function_resources %{
    "limits" => %{
      "memory" => "1024Mi"
    },
    "requests" => %{
      "memory" => "80Mi"
    }
  }

  @impl true
  def manifest(resource), do: gen_deployment(resource)

  defp gen_deployment(
         %{
           system: system,
           namespace: ns,
           name: name,
           params: params,
           labels: _labels,
           annotations: _annotations
         } = _resource
       ) do
    host_params = Map.get(params, "host")
    sidecar_params = Map.get(params, "sidecar", %{})

    replicas = Map.get(params, "replicas", @default_actor_host_function_replicas)

    replicas =
      if replicas <= 1 do
        1
      else
        replicas
      end

    embedded = Map.get(host_params, "embedded", false)

    %{
      "apiVersion" => "apps/v1",
      "kind" => "Deployment",
      "metadata" => %{
        "name" => name,
        "namespace" => ns,
        "labels" => %{"app" => name, "actor-system" => system}
      },
      "spec" => %{
        "replicas" => replicas,
        "selector" => %{
          "matchLabels" => %{"app" => name, "actor-system" => system}
        },
        "strategy" => %{
          "type" => "RollingUpdate",
          "rollingUpdate" => %{
            "maxSurge" => 1,
            "maxUnavailable" => 1
          }
        },
        "template" => %{
          "metadata" => %{
            "annotations" => %{
              "prometheus.io/port" => "9001",
              "prometheus.io/scrape" => "true"
            },
            "labels" => %{
              "app" => name,
              "actor-system" => system
            }
          },
          "spec" => %{
            "containers" => get_containers(embedded, system, name, host_params, sidecar_params),
            "terminationGracePeriodSeconds" => 120
          }
        }
      }
    }
  end

  defp get_containers(true, system, name, host_params, _sidecar_params) do
    actor_host_function_image = Map.get(host_params, "image")

    actor_host_function_envs = Map.get(host_params, "env", []) ++ @default_actor_host_function_env

    actor_host_function_ports = Map.get(host_params, "ports", [])
    actor_host_function_ports = actor_host_function_ports ++ @default_actor_host_function_ports

    actor_host_function_resources =
      Map.get(host_params, "resources", @default_actor_host_function_resources)

    [
      %{
        "name" => "actor-host-function",
        "image" => actor_host_function_image,
        "env" => actor_host_function_envs,
        "envFrom" => [
          %{
            "configMapRef" => %{
              "name" => "#{name}-sidecar-cm"
            }
          },
          %{
            "secretRef" => %{
              "name" => "#{system}-secret"
            }
          }
        ],
        "ports" => actor_host_function_ports,
        "resources" => actor_host_function_resources
      }
    ]
  end

  defp get_containers(false, system, name, host_params, sidecar_params) do
    actor_host_function_image = Map.get(host_params, "image")

    actor_host_function_envs = Map.get(host_params, "env", []) ++ @default_actor_host_function_env

    actor_host_function_ports = Map.get(host_params, "ports", [])
    actor_host_function_ports = actor_host_function_ports ++ @default_actor_host_function_ports

    actor_host_function_resources =
      Map.get(host_params, "resources", @default_actor_host_function_resources)

    [
      %{
        "name" => "spawn-sidecar",
        "image" => "#{resolve_proxy_image(sidecar_params)}",
        "env" => @default_actor_host_function_env,
        "ports" => [
          %{"containerPort" => 9000, "name" => "http"},
          %{"containerPort" => 9001, "name" => "https"},
          %{"containerPort" => 4369, "name" => "epmd"}
        ],
        "livenessProbe" => %{
          "failureThreshold" => 10,
          "httpGet" => %{
            "path" => "/health",
            "port" => 9001,
            "scheme" => "HTTP"
          },
          "initialDelaySeconds" => 300,
          "periodSeconds" => 3600,
          "successThreshold" => 1,
          "timeoutSeconds" => 1200
        },
        "resources" => actor_host_function_resources,
        "envFrom" => [
          %{
            "configMapRef" => %{
              "name" => "#{name}-sidecar-cm"
            }
          },
          %{
            "secretRef" => %{
              "name" => "#{system}-secret"
            }
          }
        ]
      },
      %{
        "name" => "actor-host-function",
        "image" => actor_host_function_image,
        "env" => actor_host_function_envs,
        "ports" => actor_host_function_ports,
        "resources" => actor_host_function_resources
      }
    ]
  end

  defp resolve_proxy_image(sidecar_params),
    do: Map.get(sidecar_params, "image", get_sidecar_image_by_env())

  defp get_sidecar_image_by_env(),
    do:
      Application.get_env(
        :spawn_operator,
        :proxy_image,
        "docker.io/eigr/spawn-proxy:0.5.0-rc.6"
      )
end
