# Add a process-compose profile for the local rider + driver backend path.
{ inputs, ... }:
{
  perSystem = perSystem@{ inputs', self', pkgs, lib, ... }: {
    process-compose.run-driver-stack-dev = {
      imports = [
        (import ./services/nammayatri.nix { inherit (perSystem) config self' inputs'; inherit inputs; })
      ];

      apiServer = false;
      services.nammayatri.enable = true;
      services.nammayatri.useCabal = true;

      settings.processes = {
        rider-dashboard-exe.disabled = true;
        provider-dashboard-exe.disabled = true;
        rider-app-drainer-exe.disabled = true;
        dynamic-offer-driver-drainer-exe.disabled = true;
        driver-offer-allocator-exe.disabled = true;
        rider-app-scheduler-exe.disabled = true;
        image-api-helper-exe.disabled = true;
        mock-fcm-exe.disabled = true;
        mock-google-exe.disabled = true;
        mock-idfy-exe.disabled = true;
        mock-sms-exe.disabled = true;
        producer-exe.disabled = true;
        rider-producer-exe.disabled = true;
        search-result-aggregator-exe.disabled = true;
        kafka-consumers-exe.disabled = true;
        unified-dashboard-exe.disabled = true;

        test-dashboard.disabled = true;
        metabase.disabled = true;
        metabase-setup.disabled = true;
        redis-commander.disabled = true;

        rider-app-exe.readiness_probe.initial_delay_seconds = lib.mkForce 15;
        dynamic-offer-driver-app-exe.readiness_probe.initial_delay_seconds = lib.mkForce 15;
      };
    };
  };
}
